import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-165：「卡片叠」首页与新类别页搬成正式，旧首页与旧类别页退役（SPEC-S0 v3 实装第一张）。
///
/// 依据 SPEC-S0 v3（SHA-256 `F52F…83F6`）第二、三、六节与第十四节，与任务卡 IC-20260923-165 的
/// 六条裁定。断言编号与任务卡子项 D 一一对应，**只扫源码与目录**：不构造视图、不碰 PhotoKit。
/// 口径：文案 key（`s0.`／`s1.`／`deck.` 开头）一律扫原文，其余扫剔过注释与字符串内容的源码。
///
/// **源码扫描，真机未覆盖**（陷阱 1）：受限提示条、扫描首帧、`VF` 三态读数、玻璃质感、排序菜单与
/// 返回钮的无障碍标签，只有 H84 能判。
final class IC165DeckFormalTests: XCTestCase {

    // MARK: - 断言 1：`Features/S0/` 目录级零 PhotoKit（裁定 二）

    func testIC165A_FeaturesS0IsPhotoKitFreeAtDirectoryLevel() throws {
        let files = try swiftFiles(inDirectory: Self.s0Directory)
        XCTAssertGreaterThanOrEqual(files.count, 10)
        for relativePath in files {
            let source = try XCTUnwrap(strippedSource(relativePath), relativePath)
            XCTAssertGreaterThan(source.count, 0, relativePath)
            for needle in [
                "import Photos",
                "PHAsset",
                "PHImageManager",
                "PHCachingImageManager",
                "PHFetch"
            ] {
                XCTAssertEqual(
                    occurrences(of: needle, in: source),
                    0,
                    relativePath + " 出现了 " + needle
                )
            }
        }
        // 正对照：取图与取日期的两只在 `Features/Shared/`，同一套 needle 在那里命中非零。
        let cover = try XCTUnwrap(strippedSource(Self.coverPath))
        XCTAssertGreaterThanOrEqual(occurrences(of: "PHImageManager", in: cover), 1)
        let dates = try XCTUnwrap(strippedSource(Self.datesPath))
        XCTAssertGreaterThanOrEqual(occurrences(of: "PHAsset", in: dates), 1)
    }

    // MARK: - 断言 2：系统版本判定只在 zoom 过渡文件（裁定 五）

    func testIC165A_AvailabilityCheckLivesOnlyInZoomTransitionFile() throws {
        var files = try swiftFiles(inDirectory: Self.s0Directory)
        files.append(Self.coverPath)
        files.append(Self.datesPath)
        var counts: [String: Int] = [:]
        for relativePath in files {
            let source = try XCTUnwrap(strippedSource(relativePath), relativePath)
            let count = occurrences(of: "#available", in: source)
            if count > 0 {
                counts[relativePath] = count
            }
        }
        XCTAssertEqual(counts, [Self.zoomPath: 2])

        // 两只页面文件级的数值字面量只剩 0／1／2（版本号 `18.0` 随 zoom 过渡抽走）。
        let allowed: Set<String> = ["0", "1", "2"]
        for relativePath in [Self.homePath, Self.pagePath] {
            let source = try XCTUnwrap(strippedSource(relativePath), relativePath)
            let literals = numericLiterals(in: source)
            XCTAssertTrue(
                literals.isSubset(of: allowed),
                relativePath + " 出现了 0／1／2 之外的裸数："
                    + literals.subtracting(allowed).sorted().joined(separator: ",")
            )
        }
    }

    // MARK: - 断言 3：宽幅封面先框后裁、命中区收在框内（SPEC-S0 v3 第十四节实装注记 ①）

    func testIC165A_CoverViewFramesThenClipsAndOwnsHitShape() throws {
        let cover = try XCTUnwrap(strippedSource(Self.coverPath))
        XCTAssertEqual(occurrences(of: "scaledToFill()", in: cover), 1)
        XCTAssertEqual(occurrences(of: ".clipped()", in: cover), 1)
        XCTAssertEqual(occurrences(of: ".contentShape(", in: cover), 1)
        let frame = try XCTUnwrap(cover.range(of: ".frame("), "封面视图没有 .frame(")
        let clipped = try XCTUnwrap(cover.range(of: ".clipped()"), "封面视图没有 .clipped()")
        let hitShape = try XCTUnwrap(cover.range(of: ".contentShape("), "封面视图没有 .contentShape(")
        XCTAssertLessThan(frame.lowerBound, clipped.lowerBound, "先裁后框：溢出的图层会盖住邻居（陷阱 24）")
        XCTAssertLessThan(clipped.lowerBound, hitShape.lowerBound, "命中区须在裁切之后收回框内")
        XCTAssertEqual(occurrences(of: "isNetworkAccessAllowed = false", in: cover), 1)
    }

    // MARK: - 断言 4：首页补齐受限提示条、扫描首帧与 `VF` 三态读数（裁定 四、五）

    func testIC165B_HomeCarriesBannerScanningHeroAndVerificationReadouts() throws {
        let home = try XCTUnwrap(strippedSource(Self.homePath))
        XCTAssertGreaterThanOrEqual(occurrences(of: "S1LimitedBannerStyle.", in: home), 3)
        XCTAssertEqual(occurrences(of: "cleanableByteCount", in: home), 0)
        XCTAssertEqual(occurrences(of: "libraryTotalByteCount == 0", in: home), 1)
        XCTAssertEqual(occurrences(of: "machine.beginVerification", in: home), 1)
        XCTAssertEqual(occurrences(of: "switch machine.verificationState {", in: home), 1)
        // 四态分派：读状态机发布的四态本身。三个分支钉在分派段内——同文件的 `VF` 读数另有
        // 一只 `switch`，它也有 `case .failed:`（IC-165 定）。
        XCTAssertEqual(occurrences(of: "switch machine.state {", in: home), 1)
        XCTAssertEqual(occurrences(of: "machine.showsCategoryRows", in: home), 0)
        let dispatch = try XCTUnwrap(
            slice(
                home,
                from: "private var content: some View {",
                to: Self.newline + "    }" + Self.newline
            ),
            "首页四态分派 `content` 没切到"
        )
        XCTAssertEqual(occurrences(of: "case .scanning, .ready:", in: dispatch), 1)
        XCTAssertEqual(occurrences(of: "case .empty:", in: dispatch), 1)
        XCTAssertEqual(occurrences(of: "case .failed:", in: dispatch), 1)
        // 展开／收起那一次 spring 是唯一的 `withAnimation(`，实参取登记的两值。
        XCTAssertEqual(occurrences(of: "withAnimation(", in: home), 1)
        let animation = try XCTUnwrap(slice(home, from: "withAnimation(", to: ") {"))
        XCTAssertGreaterThan(occurrences(of: "expandAnimationResponse", in: animation), 0)
        XCTAssertGreaterThan(occurrences(of: "expandAnimationDamping", in: animation), 0)
        for forbidden in [
            "S2AmbientBackdropView",
            "Material",
            "ultraThin",
            "colorScheme",
            "S0HomePalette",
            "s0GlassSurface"
        ] {
            XCTAssertEqual(occurrences(of: forbidden, in: home), 0, forbidden)
        }

        let homeRaw = try XCTUnwrap(sourceText(Self.homePath))
        for key in [
            "s1.limited.banner",
            "s0.home.hero.scanning",
            "s0.home.pending.checking",
            "s0.home.pending.passed",
            "s0.home.pending.failed"
        ] {
            XCTAssertEqual(occurrences(of: key, in: homeRaw), 1, key)
        }
        XCTAssertEqual(occurrences(of: "Text(\"", in: homeRaw), 0)
    }

    // MARK: - 断言 5：类别页 key 与 chrome 纪律（裁定 四、六，视觉取值节）

    func testIC165C_CategoryPageKeysAndChromeDiscipline() throws {
        let pageRaw = try XCTUnwrap(sourceText(Self.pagePath))
        XCTAssertEqual(occurrences(of: "s0.categoryPage.back", in: pageRaw), 2)
        XCTAssertEqual(occurrences(of: "s0.categoryPage.subtitle", in: pageRaw), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "s0.categoryPage.sort.size", in: pageRaw), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "s1.sort.newest_first", in: pageRaw), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "s1.sort.oldest_first", in: pageRaw), 1)
        XCTAssertEqual(occurrences(of: "s1.sort.accessibility", in: pageRaw), 2)
        XCTAssertEqual(occurrences(of: "deck.", in: pageRaw), 0)
        XCTAssertEqual(occurrences(of: "Text(\"", in: pageRaw), 0)

        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        XCTAssertEqual(occurrences(of: "S2OverlayLayout", in: page), 0)
        XCTAssertGreaterThanOrEqual(occurrences(of: "S0DeckMetrics.toast", in: page), 5)
        XCTAssertEqual(occurrences(of: "gridCheckGlyphFontSize", in: page), 1)
        // 收起导航的返回与排序两只平涂圆钮同直径 42（v3 统一）；页头排序圆钮借 S1 圆钮玻璃。
        XCTAssertGreaterThanOrEqual(occurrences(of: "compactNavBackSide", in: page), 3)
        XCTAssertEqual(occurrences(of: "S1ChromeLayout.rowHeight", in: page), 2)
        XCTAssertEqual(occurrences(of: "LongPressGesture()", in: page), 1)
        XCTAssertEqual(occurrences(of: ".simultaneousGesture(", in: page), 1)
        XCTAssertEqual(occurrences(of: "Button {", in: page), 3)
        XCTAssertEqual(occurrences(of: "s1ChromeGlassBackground(", in: page), 5)
        for forbidden in ["Material", "ultraThin", "#available"] {
            XCTAssertEqual(occurrences(of: forbidden, in: page), 0, forbidden)
        }
    }

    // MARK: - 断言 6：退役干净、登记表与目录计数（裁定 三、六）

    func testIC165C_RetirementAndRegistryCounts() throws {
        let project = try XCTUnwrap(sourceText("PhotoCleanupMVE.xcodeproj/project.pbxproj"))
        for retired in [
            "S0View.swift",
            "S0HomeMetrics.swift",
            "S0CategoryRow.swift",
            "S0CategoryPageMetrics.swift",
            "S0CategoryPageView.swift"
        ] {
            let url = repoRoot().appendingPathComponent(Self.s0Directory + "/" + retired)
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), retired)
            XCTAssertEqual(occurrences(of: " " + retired, in: project), 0, retired)
        }

        var product = String()
        for relativePath in try swiftFiles(inDirectory: "PhotoCleanupMVE", recursive: true) {
            product += try XCTUnwrap(strippedSource(relativePath), relativePath)
        }
        XCTAssertGreaterThan(product.count, 0)
        for retired in [
            "struct S0View",
            "S0View(",
            "S0HomeMetrics",
            "S0CategoryRowView",
            "S0CategoryPageMetrics",
            "S0CategoryPageView",
            "S0GlassSurface"
        ] {
            XCTAssertEqual(occurrences(of: retired, in: product), 0, retired)
        }
        // 正对照：同一份产品源码里「卡片叠」两页确实在。
        XCTAssertEqual(occurrences(of: "struct S0DeckHomeView: View {", in: product), 1)
        XCTAssertEqual(occurrences(of: "struct S0DeckCategoryPageView: View {", in: product), 1)

        let segment = try XCTUnwrap(strippedSource(Self.s0Directory + "/S0SegmentBarModel.swift"))
        XCTAssertEqual(occurrences(of: "struct S0SegmentBarModel", in: segment), 1)
        XCTAssertEqual(occurrences(of: "struct S0SegmentBarView", in: segment), 0)

        let metrics = try XCTUnwrap(strippedSource(Self.metricsPath))
        let registry = try XCTUnwrap(
            slice(metrics, from: "enum S0DeckMetrics {", to: Self.topLevelClose),
            "登记表切片没切到"
        )
        XCTAssertEqual(occurrences(of: Self.newline + "    static let ", in: registry), 195)
        let symbols = try XCTUnwrap(
            slice(metrics, from: "enum S0DeckSymbol {", to: Self.topLevelClose),
            "符号表切片没切到"
        )
        XCTAssertEqual(occurrences(of: Self.newline + "    static let ", in: symbols), 8)

        let catalog = try loadCatalogValues()
        // IC-166 B：S0-3 副句 `s0.home.hero.empty.subtitle` 一条，39 → 40。
        // IC-167：B 删首页胶囊一条、C 加排序「从小到大」一条，`s0.` 仍 40；`s0.categoryPage.` 9 → 10。
        // IC-168 E：类别页进入失败提示一条，`s0.` 40 → 41、`s0.categoryPage.` 10 → 11。
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.") }.count, 41)
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.categoryPage.") }.count, 11)
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("deck.") }.count, 0)
        for obsolete in [
            "s0.home.hero.growing",
            "s0.home.hero.library",
            "s0.home.hero.overlap",
            "s0.home.legend.rest",
            "s0.home.legend.unscanned",
            "s0.home.category.counting",
            "s0.home.category.empty",
            "s0.home.category.waiting",
            "s0.categoryPage.longPressHint"
        ] {
            XCTAssertNil(catalog[obsolete], obsolete)
        }
        XCTAssertEqual(catalog["s0.category.rest"], "其余照片")
        XCTAssertEqual(catalog["s0.home.hero.label"], "可清理的空间")

        // 跨前缀借用恰为 SPEC-S0 v3 第十四节第 3 部分登记的四条。
        // IC-167 B：SPEC-S0 v4 加待删篮入口的无障碍标签一条，四条 → 五条（目录级扫描自动含新文件）。
        var files = try swiftFiles(inDirectory: Self.s0Directory)
        files.append(Self.coverPath)
        files.append(Self.datesPath)
        var borrowed: Set<String> = []
        for relativePath in files {
            let source = try XCTUnwrap(sourceText(relativePath), relativePath)
            borrowed.formUnion(localizationKeys(in: source).filter { !$0.hasPrefix("s0.") })
        }
        XCTAssertEqual(
            borrowed,
            [
                "s1.limited.banner",
                "s1.sort.accessibility",
                "s1.sort.newest_first",
                "s1.sort.oldest_first",
                "s1.trash.accessibility"
            ]
        )
    }

    // MARK: - 路径

    private static let s0Directory = "PhotoCleanupMVE/Features/S0"
    private static let homePath = "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift"
    private static let pagePath = "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
    private static let zoomPath = "PhotoCleanupMVE/Features/S0/S0DeckZoomTransition.swift"
    private static let metricsPath = "PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift"
    private static let coverPath = "PhotoCleanupMVE/Features/Shared/S0DeckCoverView.swift"
    private static let datesPath = "PhotoCleanupMVE/Features/Shared/S0DeckAssetDates.swift"

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-156／IC-157 一致）

    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    /// 顶层类型的收口：换行 + 右花括号 + 换行。
    private static let topLevelClose = newline + "}" + newline

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// 目录下的 `.swift` 文件，返回相对仓库根的路径；`recursive` 时连子目录一起。
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

    /// 数值字面量提取，口径同 IC-148／IC-156 `numericLiterals(in:)`。
    private func numericLiterals(in source: String) -> Set<String> {
        var literals: Set<String> = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            let previous = index > 0 ? characters[index - 1] : " "
            if previous.isLetter || previous == "_" {
                // 标识符内的数字：跳过整个标识符。判据含数字，否则指针不前进、循环不终止。
                while index < characters.count,
                      characters[index].isLetter
                          || characters[index].isNumber
                          || characters[index] == "_" {
                    index += 1
                }
                continue
            }
            var end = index
            while end < characters.count,
                  characters[end].isNumber
                      || characters[end] == "."
                      || characters[end] == "_" {
                end += 1
            }
            if end < characters.count, characters[end].isLetter {
                index = end
                continue
            }
            var token = String(characters[index..<end])
            while token.hasSuffix(".") {
                token.removeLast()
            }
            token = token.replacingOccurrences(of: "_", with: "")
            if previous == "-" {
                token = "-" + token
            }
            if !token.isEmpty {
                literals.insert(token)
            }
            index = end
        }
        return literals
    }

    /// `L10n.text(` 后跳过空白取紧跟的字符串字面量，口径同 IC-147。
    private func localizationKeys(in source: String) -> Set<String> {
        var keys: Set<String> = []
        let opening = "L10n.text("
        var searchStart = source.startIndex
        while let found = source.range(
            of: opening,
            range: searchStart..<source.endIndex
        ) {
            searchStart = found.upperBound
            var cursor = found.upperBound
            while cursor < source.endIndex, source[cursor].isWhitespace {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex, source[cursor] == "\"" else {
                continue
            }
            let keyStart = source.index(after: cursor)
            guard let closing = source.range(
                of: "\"",
                range: keyStart..<source.endIndex
            ) else {
                break
            }
            keys.insert(String(source[keyStart..<closing.lowerBound]))
            searchStart = closing.upperBound
        }
        return keys
    }

    private func loadCatalogValues() throws -> [String: String] {
        let url = repoRoot()
            .appendingPathComponent("PhotoCleanupMVE/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        let root = try XCTUnwrap(object as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        var values: [String: String] = [:]
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let chinese = localizations["zh-Hans"] as? [String: Any],
                  let unit = chinese["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else {
                continue
            }
            values[key] = value
        }
        XCTAssertGreaterThan(values.count, 100)
        return values
    }
}
