import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-183：纯重构退役卡（Decision_log 第 214 条第三节）——IC-178 旧列表层的渲染链退役、过时注释订正、测试卫生。
/// 零产品行为改动；本文件只钉源码落位：1 渲染链已从 `S1View` 与整个产品源码退役（`S1RangeCardMetrics` 余三值已随 IC-184 整族退役）、
/// 页头／四态／菜单／玻璃 helper 不动；2 六处过时注释已改写（D 四处 + A8 + E3）；3 测试卫生（无调用者 helper 删除、名单加文件、
/// needle 改扫函数名本体、四个过时函数名改名、App 逐参换行）。
final class IC183RetireRenderChainTests: XCTestCase {
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

    // MARK: - 断言 1：渲染链退役

    func testIC183A_RenderChainRetired() throws {
        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        for retired in [
            "S1RangeCoverThumbnail",
            "S1CoverImageLoading",
            "S1PhotoKitCoverImageLoader",
            "coverImageLoader",
            "S1ProgressLineStyle",
            "PHImageManager",
            "PHAsset.fetchAssets",
            "scaledToFill",
            "Image(uiImage:"
        ] {
            XCTAssertEqual(occurrences(of: retired, in: s1), 0, retired)
        }
        // IC-184：`S1RangeCardMetrics` 整族退役（余三值的两个读者 `targetPixelSize`／`leadingInset` 同批退役）。
        XCTAssertEqual(occurrences(of: "S1RangeCardMetrics", in: s1), 0)
        // 页头、四态、菜单、玻璃 helper 一字不动（IC-184 起 `cardRing` 退役，前景表引用 29 → 28）。
        XCTAssertEqual(occurrences(of: "S1ChromeForeground.", in: s1), 28)
        XCTAssertEqual(occurrences(of: "s1ChromeGlassBackground(", in: s1), 4)
        XCTAssertEqual(occurrences(of: "S1RangeCoverPolicy.coverAssetID(", in: s1), 1)
        XCTAssertEqual(occurrences(of: "S1DeckListView(", in: s1), 1)
        XCTAssertEqual(occurrences(of: "S1YearPageView(", in: s1), 1)

        var product = String()
        for relativePath in try swiftFiles(inDirectory: "PhotoCleanupMVE", recursive: true) {
            product += try XCTUnwrap(strippedSource(relativePath), relativePath)
        }
        XCTAssertGreaterThan(product.count, 0)
        for retired in [
            "S1RangeCoverThumbnail",
            "S1CoverImageLoading",
            "S1PhotoKitCoverImageLoader",
            "S1ProgressLineStyle"
        ] {
            XCTAssertEqual(occurrences(of: retired, in: product), 0, retired)
        }
        // 正对照：封面仍由共享的卡片叠封面视图画；卡片叠首页仍在。
        XCTAssertEqual(occurrences(of: "struct S0DeckHomeView: View {", in: product), 1)
        XCTAssertGreaterThan(occurrences(of: "S0DeckCoverView(", in: product), 0)
    }

    // MARK: - 断言 2：过时注释已改写（原文含注释）

    func testIC183D_StaleCommentsRewritten() throws {
        for (path, stale) in [
            ("PhotoCleanupMVE/Services/S0LibraryScanService.swift", "同一个命中判定"),
            ("PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift", "showsDisclosure"),
            ("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift", "showsDisclosure"),
            ("PhotoCleanupMVE/Features/S0/S0CategoryPageSelection.swift", "不预勾任何项"),
            ("PhotoCleanupMVETests/IC162DeckPreviewTests.swift", "showsDisclosure"),
            (Self.s1ViewPath, "年卡展开区右缘")
        ] {
            let text = try XCTUnwrap(sourceText(path), path)
            XCTAssertEqual(occurrences(of: stale, in: text), 0, path + " " + stale)
        }
        // 正对照：改写后的说法各恰一处。
        let scan = try XCTUnwrap(sourceText("PhotoCleanupMVE/Services/S0LibraryScanService.swift"))
        XCTAssertEqual(occurrences(of: "同一个归属判定", in: scan), 1)
        let selection = try XCTUnwrap(sourceText("PhotoCleanupMVE/Features/S0/S0CategoryPageSelection.swift"))
        XCTAssertEqual(occurrences(of: "保留集 ∩ 当前列表", in: selection), 1)
    }

    // MARK: - 断言 3：测试卫生

    func testIC183E_TestHygiene() throws {
        let ic146 = try XCTUnwrap(sourceText("PhotoCleanupMVETests/IC146ChromeRoundTwoTests.swift"))
        XCTAssertEqual(occurrences(of: "func waitUntil(", in: ic146), 0)

        // IC147 断言 7 的名单切片（该文件别处也会点名这些文件，只数名单内）。
        let ic147 = try XCTUnwrap(sourceText("PhotoCleanupMVETests/IC147S0BehaviorTests.swift"))
        let roster = try XCTUnwrap(slice(ic147, from: "视图层与容器层一处都不许直写这三个状态量", to: "] {"))
        for added in ["S0DeckCategoryPageView.swift", "S0CleanupFlowView.swift", "S0CleanupFlowModel.swift"] {
            XCTAssertEqual(occurrences(of: "\"PhotoCleanupMVE/Features/S0/" + added + "\"", in: roster), 1, added)
        }
        XCTAssertEqual(occurrences(of: "\"PhotoCleanupMVE/", in: roster), 7, "四个既有 + 三个新增")

        let ic157 = try XCTUnwrap(sourceText("PhotoCleanupMVETests/IC157LongPressIntoS2Tests.swift"))
        XCTAssertEqual(occurrences(of: "\"makeS2Handoff(virtualRangeID:\"", in: ic157), 0)
        XCTAssertEqual(occurrences(of: "\"makeS2Handoff(\"", in: ic157), 1)
        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "makeS2Handoff(", in: app), 1)
        XCTAssertEqual(occurrences(of: "makeS2Handoff(" + Self.newline, in: app), 1, "长按交接改回逐参换行")

        for (path, old, new) in [
            ("PhotoCleanupMVETests/IC153ScanServiceTests.swift",
             "testIC153A_AggregationDedupesHeroButNotCategories",
             "testIC153A_AggregationDedupesHeroAndCategoriesByAttribution"),
            ("PhotoCleanupMVETests/IC162DeckPreviewTests.swift",
             "testIC162A_CardsKeepOrderDropEmptyAndAppendRest",
             "testIC162A_CardsKeepOrderDropEmptyAndIncludeRest"),
            ("PhotoCleanupMVETests/IC162DeckPreviewTests.swift",
             "testIC162A_RestCardOmittedWhenZero",
             "testIC162A_RestCardOmittedWhenNoRestRow"),
            ("PhotoCleanupMVETests/IC148S0VisualTests.swift",
             "testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys",
             "testIC148CAssertion10CatalogS0KeysCountAndCrossReference")
        ] {
            let text = try XCTUnwrap(sourceText(path), path)
            XCTAssertEqual(occurrences(of: "func " + old + "(", in: text), 0, old)
            XCTAssertEqual(occurrences(of: "func " + new + "(", in: text), 1, new)
        }
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
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}
