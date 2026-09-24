import Combine
import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-171：类别页收起导航条只留类别名、待删篮徽标叠到玻璃合成边界之外、长按进 S2 往返后滚动
/// 位置保留（S0 维护卡，Decision_log 第 200 条第三节第 2、4、5 条）。
///
/// 只钉本卡新增的符号与行为（惯例 46）：8 处计数改期望的既有断言已在各自文件里改（IC156／
/// IC165／IC166／IC167），`#available` 只在 zoom 过渡文件的钉子已由 IC165 断言 2 守住，
/// 本文件不重复钉。
///
/// **夹具驱动与源码扫描，真机未覆盖**（陷阱 1）：徽标发虚是否真的解决、顶排有无偏移、
/// 收起导航条整条玻璃观感、`.task` 时能否滚到远处的格子、长按封面那张时的落点，只有 H90 能判。
final class IC171CategoryPageTrioTests: XCTestCase {

    // MARK: - 断言 1：收起导航条只留类别名（裁定 一）

    func testIC171A_CompactNavTitleShowsNameOnly() throws {
        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        let pageRaw = try XCTUnwrap(sourceText(Self.pagePath))
        let title = try XCTUnwrap(
            slice(page, from: "private var compactNavTitle: some View {", to: Self.close)
        )
        XCTAssertEqual(
            occurrences(of: "S0CategoryText.displayName(for: category.id)", in: title),
            1
        )
        XCTAssertEqual(occurrences(of: ".lineLimit(1)", in: title), 1)
        XCTAssertEqual(occurrences(of: "S0ByteCountText.string(", in: title), 0)
        XCTAssertEqual(occurrences(of: "sharePercentText", in: title), 0)
        XCTAssertEqual(occurrences(of: "compactNavTitleFontSize", in: title), 1)
        XCTAssertEqual(occurrences(of: "Text(", in: title), 1)

        let titleRaw = try XCTUnwrap(
            slice(pageRaw, from: "private var compactNavTitle: some View {", to: Self.close)
        )
        XCTAssertEqual(occurrences(of: "s0.home.share", in: titleRaw), 0)

        let registry = try XCTUnwrap(strippedSource(Self.metricsPath))
        for retired in [
            "compactNavValueLetterSpacing",
            "compactNavShareFontSize",
            "compactNavShareOpacity"
        ] {
            XCTAssertEqual(occurrences(of: retired, in: registry), 0, retired)
        }
    }

    // MARK: - 断言 2：徽标经 S1 helper 叠在玻璃合成边界之外（裁定 二）

    func testIC171B_BadgeIsLaidOutsideGlassViaS1Helpers() throws {
        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        XCTAssertEqual(
            occurrences(of: "struct S1GlassBadgeAnchorKey: PreferenceKey", in: s1),
            1
        )
        XCTAssertEqual(
            occurrences(of: "func s1GlassBadgeOverlay<Badge: View>(", in: s1),
            1
        )
        XCTAssertEqual(
            occurrences(of: "func s1GlassBadgeHost<Badge: View>(", in: s1),
            1
        )
        XCTAssertEqual(
            occurrences(of: "struct S1GlassBadgeLayer<Badge: View>: View", in: s1),
            1
        )

        let overlaySlice = try XCTUnwrap(
            slice(s1, from: "func s1GlassBadgeOverlay<Badge: View>(", to: Self.close)
        )
        XCTAssertEqual(occurrences(of: "#available(iOS 26.0, *)", in: overlaySlice), 1)
        XCTAssertEqual(occurrences(of: "GlassEffectContainer {", in: overlaySlice), 1)
        XCTAssertEqual(
            occurrences(of: "overlay(alignment: .topTrailing)", in: overlaySlice),
            2
        )

        let hostSlice = try XCTUnwrap(
            slice(s1, from: "func s1GlassBadgeHost<Badge: View>(", to: Self.close)
        )
        XCTAssertEqual(occurrences(of: "#available(iOS 26.0, *)", in: hostSlice), 1)
        XCTAssertEqual(occurrences(of: "GlassEffectContainer {", in: hostSlice), 1)
        XCTAssertEqual(
            occurrences(of: "overlayPreferenceValue(S1GlassBadgeAnchorKey.self)", in: hostSlice),
            2
        )

        XCTAssertNil(S1GlassBadgeAnchorKey.defaultValue)

        let entry = try XCTUnwrap(strippedSource(Self.entryPath))
        XCTAssertEqual(occurrences(of: "struct S0BasketBadge: View", in: entry), 1)
        XCTAssertEqual(occurrences(of: ".s1GlassBadgeOverlay {", in: entry), 1)
        XCTAssertEqual(occurrences(of: "S0BasketBadge(count: count)", in: entry), 1)
        XCTAssertEqual(
            occurrences(
                of: ".anchorPreference(key: S1GlassBadgeAnchorKey.self, value: .bounds)",
                in: entry
            ),
            1
        )
        XCTAssertEqual(occurrences(of: "showsBadge ? anchor : nil", in: entry), 1)

        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        let compactNav = try XCTUnwrap(
            slice(page, from: "private var compactNav: some View {", to: Self.close)
        )
        XCTAssertEqual(occurrences(of: ".s1GlassBadgeHost {", in: compactNav), 1)
        XCTAssertEqual(
            occurrences(
                of: "S0BasketBadge(count: machine.mergedPendingDeletionCount)",
                in: compactNav
            ),
            1
        )
        let glassRange = compactNav.range(of: ".s1ChromeGlassBackground(")
        let hostRange = compactNav.range(of: ".s1GlassBadgeHost {")
        let glassLower = try XCTUnwrap(glassRange).lowerBound
        let hostLower = try XCTUnwrap(hostRange).lowerBound
        XCTAssertLessThan(glassLower, hostLower)
    }

    // MARK: - 断言 3：滚动锚点不发布、换类别与返回首页时清空（裁定 三）

    func testIC171C_ScrollAnchorIsUnpublishedAndClearedOnCategoryChange() throws {
        let model = S0CleanupFlowModel()
        XCTAssertNil(model.preservedScrollAnchor)

        var changeCount = 0
        let subscription = model.objectWillChange.sink { _ in
            changeCount += 1
        }

        model.preservedScrollAnchor = "a"
        XCTAssertEqual(changeCount, 0)

        // 正对照：发布通道是活的，类别页身份照旧发布。
        model.presentedCategory = .screenshot
        XCTAssertEqual(changeCount, 1)

        subscription.cancel()
        XCTAssertEqual(model.preservedScrollAnchor, "a")

        let modelSource = try XCTUnwrap(strippedSource(Self.modelPath))
        XCTAssertEqual(
            occurrences(of: "var preservedScrollAnchor: String? = nil", in: modelSource),
            1
        )

        let flow = try XCTUnwrap(strippedSource(Self.flowPath))
        XCTAssertEqual(
            occurrences(of: "flowModel.preservedScrollAnchor = nil", in: flow),
            2
        )
        let enterSlice = try XCTUnwrap(
            slice(flow, from: "private func enterCategory(", to: Self.close)
        )
        XCTAssertEqual(
            occurrences(of: "flowModel.preservedScrollAnchor = nil", in: enterSlice),
            1
        )
        let leaveSlice = try XCTUnwrap(
            slice(flow, from: "private func leaveCategory(", to: Self.close)
        )
        XCTAssertEqual(
            occurrences(of: "flowModel.preservedScrollAnchor = nil", in: leaveSlice),
            1
        )
        // 长按进 S2 的接线不碰锚点：总数恰等于 enter/leave 各一次之和。
        XCTAssertEqual(occurrences(of: "preservedScrollAnchor", in: flow), 2)
    }

    // MARK: - 断言 4：页面恢复被长按的那一格，只做一次（裁定 三）

    func testIC171C_PageRestoresLongPressedCellOnce() throws {
        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        XCTAssertEqual(occurrences(of: "ScrollViewReader { proxy in", in: page), 1)
        XCTAssertEqual(occurrences(of: "restoreScrollAnchor(using: proxy)", in: page), 1)
        XCTAssertEqual(
            occurrences(of: "proxy.scrollTo(anchor, anchor: .center)", in: page),
            1
        )
        XCTAssertEqual(
            occurrences(
                of: "flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil",
                in: page
            ),
            1
        )
        XCTAssertEqual(occurrences(of: "flowModel.preservedScrollAnchor", in: page), 2)
        XCTAssertEqual(occurrences(of: "scrollPosition", in: page), 0)

        let restoreSlice = try XCTUnwrap(
            slice(
                page,
                from: "private func restoreScrollAnchor(using proxy: ScrollViewProxy)",
                to: Self.close
            )
        )
        XCTAssertEqual(
            occurrences(of: "selection.items.contains(where:", in: restoreSlice),
            1
        )

        let gridCellSlice = try XCTUnwrap(
            slice(page, from: "private func gridCell(", to: Self.close)
        )
        let anchorWriteRange = gridCellSlice.range(
            of: "flowModel.preservedScrollAnchor = isHeaderCollapsed ? item.id : nil"
        )
        let onLongPressRange = gridCellSlice.range(of: "onLongPress(")
        let anchorWriteLower = try XCTUnwrap(anchorWriteRange).lowerBound
        let onLongPressLower = try XCTUnwrap(onLongPressRange).lowerBound
        XCTAssertLessThan(anchorWriteLower, onLongPressLower)
    }

    // MARK: - 路径

    private static let pagePath = "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
    private static let metricsPath = "PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift"
    private static let entryPath = "PhotoCleanupMVE/Features/S0/S0BasketEntryView.swift"
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let modelPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift"
    private static let flowPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift"

    // MARK: - 源码扫描 helper（口径与 IC-167 一致，文件私有不能跨文件调用，陷阱 23）

    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    private static let close = newline + "    }" + newline

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

    private func slice(
        _ source: String,
        from start: String,
        to end: String
    ) -> String? {
        guard let startRange = source.range(of: start),
              let endRange = source.range(
                  of: end,
                  range: startRange.upperBound..<source.endIndex
              ) else {
            return nil
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }
}
