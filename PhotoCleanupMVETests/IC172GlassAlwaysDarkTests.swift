import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-172：玻璃一律按系统深色模式的效果、不随浅／深色变（④ 第 200 条第三节第 1 条、第 201 条 Lynn 答复第 4 条）。
///
/// 像素探针照 `S2CalibrationHarnessTests.testIC067G39…` 的手法：`UIHostingController` 装进可见窗口，
/// 设 `overrideUserInterfaceStyle`，`drawHierarchy(afterScreenUpdates: true)` 截屏，取玻璃中心一个像素的
/// 灰度（RGB 均值）。玻璃背后垫固定 sRGB 中灰，外观切换只可能经玻璃本身改变取值。
/// 正对照（不加覆盖的系统材质、裸系统玻璃）两侧必须不同——证明夹具看得见外观差；被测两侧必须相同：玻璃 helper 与
/// 容器路径等于裸玻璃的深色侧，三种材质配方等于同一棵树不加覆盖时的深色侧（参照一律只差覆盖这一个修饰符）；
/// 回落配方只判两侧相同（见该测试注释）。控制台每组打一行 `IC172_PROBE`，红了先看这几行。
final class IC172GlassAlwaysDarkTests: XCTestCase {
    private static let canvasSize = CGSize(width: 240, height: 120)
    private static let glassSize = CGSize(width: 160, height: 60)
    private static let sameAccuracy = 3
    private static let materialMinimumDifference = 12
    private static let glassMinimumDifference = 6

    private static let s1Path = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let s2Path = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let darkNeedle = "colorScheme, .dark)"

    // MARK: - 正对照：夹具看得见外观差

    func testIC172A_MaterialControlFollowsInterfaceStyle() {
        let material = grayPair("material") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
        }
        XCTAssertGreaterThanOrEqual(
            abs(material.light - material.dark),
            Self.materialMinimumDifference,
            "不加覆盖的系统材质两侧几乎相同：夹具看不见外观差，本卡像素断言无判别力"
        )
    }

    func testIC172A_RawGlassControlFollowsInterfaceStyle() {
        guard #available(iOS 26.0, *) else {
            XCTFail("CI 须跑 iOS 26 运行时")
            return
        }
        let glass = grayPair("rawGlass") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .glassEffect(.regular, in: Capsule())
        }
        XCTAssertGreaterThanOrEqual(
            abs(glass.light - glass.dark),
            Self.glassMinimumDifference,
            "不加覆盖的系统玻璃两侧几乎相同：夹具看不见玻璃的外观差"
        )
    }

    // MARK: - 被测：两侧相同且落在深色一侧

    func testIC172A_S1GlassHelperIsDarkInBothStyles() {
        guard #available(iOS 26.0, *) else {
            XCTFail("CI 须跑 iOS 26 运行时")
            return
        }
        let helper = grayPair("s1Helper") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .s1ChromeGlassBackground(in: Capsule())
        }
        XCTAssertLessThanOrEqual(
            abs(helper.light - helper.dark),
            Self.sameAccuracy,
            "玻璃 helper 随系统外观变了"
        )
        let glass = grayPair("rawGlassReference") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .glassEffect(.regular, in: Capsule())
        }
        XCTAssertLessThanOrEqual(
            abs(helper.light - glass.dark),
            Self.sameAccuracy,
            "浅色外观下玻璃 helper 不是系统深色玻璃的效果"
        )
    }

    func testIC172A_S1LegacyRecipeIgnoresInterfaceStyle() {
        let legacy = grayPair("s1Legacy") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .s1LegacyChromeGlassBackground(in: Capsule())
        }
        // 两侧相同即覆盖生效。「落在深色侧」由跨运行数据印证（①）：IC-173 #352 在未加覆盖的 `main` 上量得回落配方
        // 系统深色 149，IC-172 #350／#351 加覆盖后两侧都是 149。回落配方的手写拷贝与函数本体渲染不同（#351 拷贝
        // 172／104），不能在这里拿拷贝当参照。
        XCTAssertLessThanOrEqual(
            abs(legacy.light - legacy.dark),
            Self.sameAccuracy,
            "回落配方随系统外观变了"
        )
    }

    func testIC172B_GlassContainerPathIsDarkInBothStyles() {
        let contained = grayPair("s1GlassBadgeOverlay") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .s1ChromeGlassBackground(in: Capsule())
                .s1GlassBadgeOverlay {
                    EmptyView()
                }
        }
        XCTAssertLessThanOrEqual(
            abs(contained.light - contained.dark),
            Self.sameAccuracy,
            "玻璃容器路径随系统外观变了"
        )
    }

    // MARK: - 子项 C：三种系统材质配方加覆盖后等于系统深色（对照 = 同一棵树不加覆盖）

    /// IC-173 #352（①）：各配方加覆盖后逐像素等于系统深色——裸 ultraThin 99、regular 64、菜单配方 7。
    func testIC172C_MaterialRecipesUnderOverrideAreSystemDark() {
        let toastReference = grayPair("toastReference") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.regularMaterial, in: Capsule())
        }
        let toast = grayPair("toastOverride") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.regularMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
        }
        assertOverride(toast, matchesDarkOf: toastReference, "toast")

        let hintReference = grayPair("hintReference") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
        }
        let hint = grayPair("hintOverride") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
        }
        assertOverride(hint, matchesDarkOf: hintReference, "hint")

        let menuReference = grayPair("menuReference") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    RoundedRectangle(cornerRadius: S1MenuStyle.cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: S1MenuStyle.cornerRadius)
                        .fill(
                            Color(uiColor: .systemBackground)
                                .opacity(S1MenuStyle.backgroundOpacity)
                        )
                }
        }
        let menu = grayPair("menuOverride") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    RoundedRectangle(cornerRadius: S1MenuStyle.cornerRadius)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: S1MenuStyle.cornerRadius)
                        .fill(
                            Color(uiColor: .systemBackground)
                                .opacity(S1MenuStyle.backgroundOpacity)
                        )
                }
                .environment(\.colorScheme, .dark)
        }
        assertOverride(menu, matchesDarkOf: menuReference, "menu")
    }

    private func assertOverride(
        _ overridden: (light: Int, dark: Int),
        matchesDarkOf reference: (light: Int, dark: Int),
        _ label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertGreaterThanOrEqual(
            abs(reference.light - reference.dark),
            Self.materialMinimumDifference,
            label + " 对照两侧几乎相同：无判别力",
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            abs(overridden.light - overridden.dark),
            Self.sameAccuracy,
            label + " 加覆盖后仍随系统外观变",
            file: file,
            line: line
        )
        XCTAssertLessThanOrEqual(
            abs(overridden.light - reference.dark),
            Self.sameAccuracy,
            label + " 加覆盖后不是系统深色的效果",
            file: file,
            line: line
        )
    }

    // MARK: - 源码：十三处覆盖逐处落位，整页不换肤

    func testIC172ABC_SourceWiring() throws {
        let s1 = try XCTUnwrap(strippedSource(Self.s1Path))
        let s2 = try XCTUnwrap(strippedSource(Self.s2Path))
        XCTAssertEqual(occurrences(of: Self.darkNeedle, in: s1), 7)
        XCTAssertEqual(occurrences(of: Self.darkNeedle, in: s2), 6)
        for source in [s1, s2] {
            XCTAssertEqual(occurrences(of: "preferredColorScheme", in: source), 0)
            XCTAssertEqual(occurrences(of: "overrideUserInterfaceStyle", in: source), 0)
            XCTAssertEqual(occurrences(of: "colorScheme, .light)", in: source), 0)
        }
        let close = Self.newline + "    }" + Self.newline
        for start in [
            "func s1ChromeGlassBackground<S: InsettableShape>(",
            "func s1LegacyChromeGlassBackground<S: InsettableShape>(",
            "private var chromeBar: some View {",
            "func s1GlassBadgeOverlay<Badge: View>(",
            "func s1GlassBadgeHost<Badge: View>(",
            "private var feedbackToastOverlay: some View {",
            "private func menuContainer<Content: View>("
        ] {
            let body = try XCTUnwrap(slice(s1, from: start, to: close), start)
            XCTAssertEqual(occurrences(of: Self.darkNeedle, in: body), 1, start)
        }
        for start in [
            "func s2ChromeGlassBackground<S: InsettableShape>(",
            "func s2LegacyChromeGlassBackground<S: InsettableShape>(",
            "private var topBar: some View {",
            "private var actionBar: some View {",
            "private func feedbackToastOverlay("
        ] {
            let body = try XCTUnwrap(slice(s2, from: start, to: close), start)
            XCTAssertEqual(occurrences(of: Self.darkNeedle, in: body), 1, start)
        }
        let hint = try XCTUnwrap(
            slice(
                s2,
                from: "if tutorial.activeStep == .albumGuide {",
                to: ".overlay(alignment: .bottom) {"
            )
        )
        XCTAssertEqual(occurrences(of: Self.darkNeedle, in: hint), 1)
        // 材质之后才覆盖：覆盖包住材质与文字两者。
        for (source, material) in [
            (s1, ".background(.regularMaterial, in: Capsule())"),
            (s2, ".background(.regularMaterial, in: Capsule())"),
            (s2, ".background(.ultraThinMaterial, in: Capsule())")
        ] {
            let materialRange = try XCTUnwrap(source.range(of: material), material)
            let tail = String(source[materialRange.upperBound...])
            let nextDark = try XCTUnwrap(tail.range(of: Self.darkNeedle), material)
            let nextPadding = try XCTUnwrap(tail.range(of: ".padding("), material)
            XCTAssertLessThan(nextDark.lowerBound, nextPadding.lowerBound, material)
        }
        // 标定面板三处系统材质不纳入（④ 第 201 条 Lynn 答复第 4 条）。
        XCTAssertEqual(occurrences(of: ".background(.regularMaterial)", in: s2), 3)
    }

    // MARK: - 像素取样（口径照 S2CalibrationHarnessTests 的 viewportBackgroundPixelGray／pixelGray）

    private func grayPair<Content: View>(
        _ arm: String,
        @ViewBuilder content: () -> Content
    ) -> (light: Int, dark: Int) {
        let view = content()
        let light = centerGray(of: view, style: .light)
        let dark = centerGray(of: view, style: .dark)
        print("IC172_PROBE arm=" + arm + " light=" + String(light) + " dark=" + String(dark))
        return (light, dark)
    }

    private func centerGray<Content: View>(
        of content: Content,
        style: UIUserInterfaceStyle
    ) -> Int {
        let root = ZStack {
            Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        let controller = UIHostingController(rootView: root)
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.canvasSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        controller.overrideUserInterfaceStyle = style
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        controller.view.frame = CGRect(origin: .zero, size: Self.canvasSize)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            bounds: controller.view.bounds,
            format: format
        ).image { _ in
            _ = controller.view.drawHierarchy(
                in: controller.view.bounds,
                afterScreenUpdates: true
            )
        }
        return pixelGray(
            image: image,
            point: CGPoint(
                x: Self.canvasSize.width / 2,
                y: Self.canvasSize.height / 2
            )
        )
    }

    private func pixelGray(image: UIImage, point: CGPoint) -> Int {
        guard let source = image.cgImage else {
            XCTFail("截图缺少像素数据")
            return -1
        }
        let x = min(source.width - 1, max(0, Int(point.x * image.scale)))
        let y = min(source.height - 1, max(0, Int(point.y * image.scale)))
        guard let cropped = source.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            XCTFail("无法裁取像素")
            return -1
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let didDraw = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard didDraw else {
            XCTFail("无法创建像素取样上下文")
            return -1
        }
        return (Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / 3
    }

    // MARK: - 源码扫描 helper（照抄 IC167BasketEntryAndTailTests 的同名私有成员，一字不改）

    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

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
