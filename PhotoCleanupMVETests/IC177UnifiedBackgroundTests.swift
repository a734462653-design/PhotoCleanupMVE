import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-177：全屏背景统一（Decision_log 第 205 条第二节第 1 条；第 203 条裁定一挂账结清）。
///
/// S1／S3／S4／S5 四页的根背景、卡底、占位、分隔线、正文与次要文字、S5 hero 与主按钮全部改成「空间清理」
/// 的恒定色板（`S0DeckMetrics`），S2 幕底同步为 `#0B0F0D`。断言两类：颜色在浅／深两种 trait 下解析成同一组
/// 分量（夹具驱动，真机观感归 H93）；四页源码里不再出现任何系统动态色写法，而 IC-148／IC-172 的正对照仍成立。
final class IC177UnifiedBackgroundTests: XCTestCase {
    private static let s1Path = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let s3Path = "PhotoCleanupMVE/Features/S3/S3View.swift"
    private static let s4Path = "PhotoCleanupMVE/Features/S4/S4View.swift"
    private static let s5Path = "PhotoCleanupMVE/Features/S5/S5View.swift"
    private static let ambientPath = "PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift"

    // MARK: - 断言 1：前景表是恒定色板，浅／深同值

    func testIC177A_ForegroundTableIsFixedPaletteInBothAppearances() {
        assertFixed(S1ChromeForeground.primary, red: 255, green: 251, blue: 245, alpha: 1)
        assertFixed(S1ChromeForeground.secondary, red: 255, green: 251, blue: 245, alpha: 0.62)
        assertFixed(S1ChromeForeground.tertiary, red: 255, green: 251, blue: 245, alpha: 0.45)
        assertFixed(S1ChromeForeground.separator, red: 255, green: 251, blue: 245, alpha: 0.14)
        assertFixed(S1ChromeForeground.accent, red: 242, green: 107, blue: 78, alpha: 1)
        assertFixed(S1ChromeForeground.pageBackground, red: 11, green: 15, blue: 13, alpha: 1)
        assertFixed(S1ChromeForeground.cardBackground, red: 22, green: 27, blue: 24, alpha: 1)
        XCTAssertEqual(S1ChromeForeground.secondaryOpacity, 0.62, accuracy: 0.000_001)
        XCTAssertEqual(S1ChromeForeground.tertiaryOpacity, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(S1ChromeForeground.separatorOpacity, 0.14, accuracy: 0.000_001)
        // 徽标描边随之恒定：垃圾桶徽标取页面底色，范围卡红点取卡底。
        assertFixed(S1NotificationBadgeStyle.chromeRing, red: 11, green: 15, blue: 13, alpha: 1)
        assertFixed(S1NotificationBadgeStyle.cardRing, red: 22, green: 27, blue: 24, alpha: 1)
    }

    // MARK: - 断言 2：年卡垫层、S5 hero 与 S2 幕底都是定值

    func testIC177B_YearStackHeroPaletteAndAmbientBaseAreFixed() {
        assertFixed(S1YearStackStyle.layerOneColor, red: 58, green: 58, blue: 60, alpha: 1)
        assertFixed(S1YearStackStyle.layerTwoColor, red: 47, green: 47, blue: 49, alpha: 1)
        assertFixed(S5HeroPalette.success, red: 111, green: 214, blue: 190, alpha: 1)
        assertFixed(S5HeroPalette.warning, red: 255, green: 159, blue: 10, alpha: 1)
        assertFixed(S5HeroPalette.neutral, red: 255, green: 251, blue: 245, alpha: 0.45)
        // 幕底统一为 #0B0F0D；绿色相不动（光晕与提亮仍按 IC-151 配方）。
        assertFixed(S2AmbientMetrics.baseColor, red: 11, green: 15, blue: 13, alpha: 1)
        assertFixed(S2AmbientMetrics.tintColor, red: 122, green: 196, blue: 158, alpha: 1)
        assertFixed(S0DeckMetrics.background, red: 11, green: 15, blue: 13, alpha: 1)
    }

    // MARK: - 断言 3：四页源码零系统动态色，正对照仍成立

    func testIC177C_PagesCarryNoDynamicColorsAndPositiveControlsHold() throws {
        let dynamicNeedles = [
            "systemGroupedBackground", "secondarySystemGroupedBackground", "secondarySystemFill",
            "tertiaryLabel", "accentColor", "systemRed", "systemGreen", "systemOrange",
            "Color.primary", "Color.secondary", "uiColor: .separator", "Color(uiColor:", "systemBackground",
            "userInterfaceStyle", "dynamicColor("
        ]
        let expectations: [(String, Int, Int, Int)] = [
            (Self.s1Path, 31, 7, 1),
            (Self.s3Path, 18, 0, 2),
            (Self.s4Path, 7, 0, 2),
            (Self.s5Path, 19, 1, 1)
        ]
        for (path, foregroundUses, paletteUses, spinners) in expectations {
            let stripped = try XCTUnwrap(strippedSource(path), path)
            for needle in dynamicNeedles {
                XCTAssertEqual(occurrences(of: needle, in: stripped), 0, path + " " + needle)
            }
            XCTAssertEqual(occurrences(of: "S1ChromeForeground.", in: stripped), foregroundUses, path)
            XCTAssertEqual(occurrences(of: "S0DeckMetrics.", in: stripped), paletteUses, path)
            // 默认样式的转圈也随系统外观：每个都带前景表的 tint。
            XCTAssertEqual(occurrences(of: "ProgressView()", in: stripped), spinners, path)
            XCTAssertEqual(occurrences(of: "ProgressView().tint(S1ChromeForeground.secondary)", in: stripped), spinners, path)
        }

        // IC-148 断言 2 与 IC-172 的正对照：S1View 仍有 `.primary`（成员名）、`Material`／`ultraThin`（回落玻璃、菜单、toast）、七处深色覆盖。
        let s1 = try XCTUnwrap(strippedSource(Self.s1Path))
        XCTAssertGreaterThan(occurrences(of: ".primary", in: s1), 0)
        XCTAssertGreaterThan(occurrences(of: "Material", in: s1), 0)
        XCTAssertGreaterThan(occurrences(of: "ultraThin", in: s1), 0)
        XCTAssertEqual(occurrences(of: "colorScheme, .dark)", in: s1), 7)
        XCTAssertEqual(occurrences(of: "s1ChromeGlassBackground(", in: s1), 4, "玻璃 helper 不动")

        let ambient = try XCTUnwrap(sourceText(Self.ambientPath))
        XCTAssertEqual(occurrences(of: "green: 15.0 / 255", in: ambient), 1)
        XCTAssertEqual(occurrences(of: "blue: 13.0 / 255", in: ambient), 1)
        XCTAssertEqual(occurrences(of: "green: 26.0 / 255", in: ambient), 0)
    }

    // MARK: - 夹具

    /// 在浅色与深色两种 trait 下都解析成同一组分量（0～255；alpha 直接比）。
    private func assertFixed(
        _ color: Color,
        red: Int,
        green: Int,
        blue: Int,
        alpha: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            XCTAssertTrue(resolved.getRed(&r, green: &g, blue: &b, alpha: &a), file: file, line: line)
            XCTAssertEqual(r * 255, CGFloat(red), accuracy: 0.6, "red style=\(style.rawValue)", file: file, line: line)
            XCTAssertEqual(g * 255, CGFloat(green), accuracy: 0.6, "green style=\(style.rawValue)", file: file, line: line)
            XCTAssertEqual(b * 255, CGFloat(blue), accuracy: 0.6, "blue style=\(style.rawValue)", file: file, line: line)
            XCTAssertEqual(a, alpha, accuracy: 0.005, "alpha style=\(style.rawValue)", file: file, line: line)
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
