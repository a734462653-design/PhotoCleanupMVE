import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-180：S5 五步竖排引导（SPEC-S5 v6 第三节：文字说明 + 五步；Decision_log 第 205 条第二节「S5 五步」）。
///
/// 断言 1 钉五步登记与规格原句，2 钉五个 SF Symbol 在宿主上存在（③ → ①），3 钉视觉登记值，4 钉源码落位
/// （S5View 引导卡两部分、新文件纪律、IC177 三个计数不变），5 钉目录（五条新 key、`boundary_notice` 改规格原句）。
/// 行高、编号圆与符号的观感归 H95 真机。
final class IC180GuideStepsTests: XCTestCase {
    private static let s5ViewPath = "PhotoCleanupMVE/Features/S5/S5View.swift"
    private static let guidePath = "PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let stepKeys = ["s5.guide.step1", "s5.guide.step2", "s5.guide.step3", "s5.guide.step4", "s5.guide.step5"]
    /// SPEC-S5 v6 `:114`／`:117-121` 原句。
    private static let introText = "照片仍由系统保留。清空「最近删除」后才真正释放空间。应用无法读取或清空该位置。"
    private static let stepTexts = [
        "打开系统「照片」",
        "进入「精选集」，向下找到「最近删除」",
        "打开「最近删除」",
        "轻点「选择」",
        "轻点「更多 (…)」，选择「全部删除」"
    ]

    // MARK: - 断言 1：五步登记与规格原句

    func testIC180A_FiveStepsInSpecOrderWithSpecSentences() {
        XCTAssertEqual(S5GuideStep.allCases.map(\.rawValue), [1, 2, 3, 4, 5])
        XCTAssertEqual(S5GuideStep.allCases.map(\.text), Self.stepTexts)
        XCTAssertEqual(S5GuideStep.allCases.map(\.isLeadStep), [true, false, false, false, false])
        XCTAssertEqual(Set(S5GuideStep.allCases.map(\.symbolName)).count, 5, "五个符号互异")
        for key in Self.stepKeys {
            XCTAssertNotEqual(L10n.text(key), key, key)
        }
        XCTAssertEqual(L10n.text("s5.recently_deleted.boundary_notice"), Self.introText)
        XCTAssertFalse(L10n.text("s5.recently_deleted.boundary_notice").contains("截图"))
        XCTAssertFalse(L10n.text("s5.recently_deleted.boundary_notice").contains("实用工具"), "导航交给五步，说明只讲边界")
    }

    // MARK: - 断言 2：五个 SF Symbol 在宿主上存在

    func testIC180B_SymbolsExistOnHost() {
        for step in S5GuideStep.allCases {
            XCTAssertNotNil(UIImage(systemName: step.symbolName), step.symbolName)
        }
        XCTAssertEqual(S5GuideSymbol.openPhotos, "photo.on.rectangle")
        XCTAssertEqual(S5GuideSymbol.openCollections, "rectangle.stack")
        XCTAssertEqual(S5GuideSymbol.openRecentlyDeleted, "trash")
        XCTAssertEqual(S5GuideSymbol.tapSelect, "checkmark.circle")
        XCTAssertEqual(S5GuideSymbol.tapMoreDeleteAll, "ellipsis.circle")
    }

    // MARK: - 断言 3：视觉登记值

    func testIC180C_MetricsMatchCanvas() {
        XCTAssertEqual(S5GuideMetrics.introBottomSpacing, 12)
        XCTAssertEqual(S5GuideMetrics.rowSpacing, 6)
        XCTAssertEqual(S5GuideMetrics.rowMinHeight, 44)
        XCTAssertEqual(S5GuideMetrics.leadSpacing, 14)
        XCTAssertEqual(S5GuideMetrics.numberCircleSide, 28)
        XCTAssertEqual(S5GuideMetrics.numberFontSize, 14)
        XCTAssertEqual(S5GuideMetrics.numberRingWidth, 1.5)
        XCTAssertEqual(S5GuideMetrics.numberRingOpacity, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(S5GuideMetrics.numberTextOpacity, 0.8, accuracy: 0.000_001)
        XCTAssertEqual(S5GuideMetrics.textFontSize, 15)
        XCTAssertEqual(S5GuideMetrics.textLineSpacing, 21)
        XCTAssertEqual(S5GuideMetrics.symbolPointSize, 18)
    }

    // MARK: - 断言 4：源码落位

    func testIC180D_SourceWiringAndDiscipline() throws {
        let s5 = try XCTUnwrap(strippedSource(Self.s5ViewPath))
        let s5Raw = try XCTUnwrap(sourceText(Self.s5ViewPath))
        // IC177 断言 3 的三个计数不变；引导卡两部分在同一张卡里。
        XCTAssertEqual(occurrences(of: "S1ChromeForeground.", in: s5), 19)
        XCTAssertEqual(occurrences(of: "S0DeckMetrics.", in: s5), 1)
        XCTAssertEqual(occurrences(of: "ProgressView()", in: s5), 1)
        XCTAssertEqual(occurrences(of: "S5GuideStepsView()", in: s5), 1)
        XCTAssertEqual(occurrences(of: "S5GuideMetrics.introBottomSpacing", in: s5), 1)
        XCTAssertEqual(occurrences(of: "\"s5.recently_deleted.boundary_notice\"", in: s5Raw), 1)
        let card = try XCTUnwrap(slice(s5, from: "private var guidanceCard: some View {", to: "private func cardBackground("))
        XCTAssertEqual(occurrences(of: "S5GuideStepsView()", in: card), 1)
        XCTAssertEqual(occurrences(of: "L10n.text(", in: card), 1, "首句仍取同一条 key")
        XCTAssertEqual(occurrences(of: "S5CardMetrics.guidanceFontSize", in: card), 2, "首句字号与行高登记不动")
        XCTAssertEqual(occurrences(of: "cardBackground(cornerRadius: S5CardMetrics.cornerRadius)", in: card), 1, "容器沿用引导卡登记")
        XCTAssertEqual(occurrences(of: "VStack(alignment: .leading, spacing: S5GuideMetrics.introBottomSpacing)", in: card), 1)
        XCTAssertEqual(occurrences(of: "if presentation.showsGuidanceCard {", in: s5), 1, "挂载点与两态口径不动")

        // 新文件纪律：无裸字符串文案、无系统材质、无动态外观、无 actor 标注、无按钮与手势；色只走前景表。
        let guide = try XCTUnwrap(strippedSource(Self.guidePath))
        let guideRaw = try XCTUnwrap(sourceText(Self.guidePath))
        XCTAssertEqual(occurrences(of: "Text(\"", in: guideRaw), 0)
        XCTAssertEqual(occurrences(of: "return \"", in: guideRaw), 0)
        XCTAssertEqual(occurrences(of: "import ", in: guideRaw), 1, "只 import SwiftUI")
        for needle in ["Material", "colorScheme", "Color(uiColor:", "@MainActor", "Button", "onTapGesture", "Link(", "openURL", "S0DeckMetrics."] {
            XCTAssertEqual(occurrences(of: needle, in: guide), 0, needle)
        }
        // IC177 的十五个动态色 needle 同样为 0：新文件恒深色，5.3 复用时不许回退到系统色。
        for needle in [
            "systemGroupedBackground", "secondarySystemGroupedBackground", "secondarySystemFill",
            "tertiaryLabel", "accentColor", "systemRed", "systemGreen", "systemOrange",
            "Color.primary", "Color.secondary", "uiColor: .separator", "systemBackground",
            "userInterfaceStyle", "dynamicColor(", "preferredColorScheme"
        ] {
            XCTAssertEqual(occurrences(of: needle, in: guide), 0, needle)
        }
        XCTAssertEqual(occurrences(of: "S1ChromeForeground.", in: guide), 6, "正文、实心底、实心字、描边、描边字、符号")
        XCTAssertEqual(occurrences(of: "ForEach(S5GuideStep.allCases, id: \\.rawValue)", in: guide), 1)
        XCTAssertEqual(occurrences(of: "strokeBorder(", in: guide), 1, "第 2～5 步描边")
        XCTAssertEqual(occurrences(of: "in: Circle())", in: guide), 1, "第 1 步实心")
        XCTAssertEqual(occurrences(of: ".accessibilityHidden(true)", in: guide), 1, "行尾符号纯装饰")
        XCTAssertEqual(occurrences(of: ".accessibilityElement(children: .combine)", in: guide), 1, "每行一个焦点")
        let metrics = try XCTUnwrap(slice(guide, from: "enum S5GuideMetrics {", to: "\n}\n"))
        XCTAssertEqual(occurrences(of: "static let ", in: metrics), 12, "登记值恰十二个")
        let symbols = try XCTUnwrap(slice(guide, from: "enum S5GuideSymbol {", to: "\n}\n"))
        XCTAssertEqual(occurrences(of: "static let ", in: symbols), 5)
        for key in Self.stepKeys {
            XCTAssertEqual(occurrences(of: "\"" + key + "\"", in: guideRaw), 1, key)
        }
    }

    // MARK: - 断言 5：目录

    func testIC180E_CatalogGainsFiveKeysAndIntroIsSpecSentence() throws {
        let catalog = try XCTUnwrap(sourceText(Self.catalogPath))
        for key in Self.stepKeys {
            XCTAssertEqual(occurrences(of: "\"" + key + "\" : {", in: catalog), 1, key)
        }
        XCTAssertEqual(occurrences(of: "\"s5.recently_deleted.boundary_notice\" : {", in: catalog), 1)
        XCTAssertEqual(occurrences(of: "\"value\" : \"" + Self.introText + "\"", in: catalog), 1)
        for text in Self.stepTexts {
            XCTAssertEqual(occurrences(of: "\"value\" : \"" + text + "\"", in: catalog), 1, text)
        }
        XCTAssertEqual(occurrences(of: "实用工具", in: catalog), 0)
    }

    // MARK: - 夹具

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
