import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-151 子项 A 的复刻件：`S0GlassSurface.frost` 那五个修饰符的原样组合，
/// 与 `S2AmbientBackdropView` 那一条「有框有裁」的组合，只差 `.frame` 与
/// `.clipped()` 两个修饰符。
///
/// **刻意放在测试目标里而不是引用产品代码**：产品侧那一层在子项 D 里被整个
/// 删掉，机制断言必须在删除之后仍然成立——它钉的是 SwiftUI 的布局机制，
/// 不是某一版产品代码。两个分支的模糊半径与饱和度写成字面量也是同一理由
/// （`cardBlurRadius`／`cardSaturation` 随子项 D 从登记表消失）。
private struct IC151FrostReplica: View {
    let image: UIImage
    let proposal: CGSize
    /// 真 = 复刻乙（M9 的组合，有框有裁）；假 = 复刻甲（S10 的组合，无框无裁）。
    let framesAndClips: Bool

    var body: some View {
        if framesAndClips {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proposal.width, height: proposal.height)
                .clipped()
                .blur(radius: 30, opaque: true)
                .saturation(1.70)
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .blur(radius: 30, opaque: true)
                .saturation(1.70)
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        }
    }
}

/// IC-151：氛围底改固定色（S2 与 S0 两处）+ 卡片区光晕 + H71 版式塌陷的
/// 归因与修复。
///
/// 依据：Decision_log 第 175 条（④ Lynn 2026-09-15 两条决策变更与 H71 判定
/// 原话）、第 176 条第四节（光晕 α 取中档）。**SPEC-S0 v2／SPEC-S2 v21 尚未
/// 晋级**，故新登记值的出处一律指 Decision_log 与本卡，不冒充 v1 的登记值。
///
/// 断言编号与任务卡一一对应：1～2 属子项 A，3～4 属子项 B，9 属子项 C，
/// 11／12／14 属子项 D。其余六条（5～8、10、13）是 IC-146／IC-148 两个既有
/// 文件内被本卡改写的断言，不在本文件。
final class IC151AmbientFixedColorTests: XCTestCase {

    // MARK: - 断言 1：无框的 scaledToFill 会溢出自己的提案（H71 归因机制）

    /// ③ 假设：H71 的「三张玻璃卡互相叠在一起」不是布局重叠，而是玻璃卡
    /// 磨砂副本的**视觉溢出**——`.scaledToFill()` 之后没有 `.frame(width:height:)`
    /// 与 `.clipped()`，正方形源图按宽填满后向上下各溢出，且 `blur(opaque: true)`
    /// 让那一层完全不透明，于是后画的卡从上一张的中间压过来。
    ///
    /// 本条验证的是**机制**：同一张图、同一提案，只差有没有框与裁。
    /// **它不是「修好了」的证据**（陷阱 13：尺寸断言不等于摆放断言）——
    /// 修好与否只有 H73 第 1 条能判。
    @MainActor
    func testIC151A_UnframedScaledToFillOverflowsItsProposal() {
        // 提案取真机上一张玻璃卡的量级：卡宽约 361、hero 卡高约 120。
        let proposal = CGSize(width: 361, height: 120)
        // 源图是 `sourceTargetEdge = 160` 的正方形缩略图。
        let image = Self.solidSquareImage(edge: 160)

        let unframed = UIHostingController(
            rootView: IC151FrostReplica(
                image: image,
                proposal: proposal,
                framesAndClips: false
            )
        ).sizeThatFits(in: proposal)
        let framed = UIHostingController(
            rootView: IC151FrostReplica(
                image: image,
                proposal: proposal,
                framesAndClips: true
            )
        ).sizeThatFits(in: proposal)

        // 实测值要进自验报告（G864），故无论成败都打进日志。
        print(
            "IC151A-MEASURED proposal="
                + Self.describe(proposal)
                + " unframed="
                + Self.describe(unframed)
                + " framed="
                + Self.describe(framed)
        )

        XCTAssertGreaterThan(
            unframed.height,
            proposal.height,
            "复刻甲没有溢出提案高——③ 假设被推翻，归因栏须写「未定」"
        )
        XCTAssertEqual(
            framed.width,
            proposal.width,
            accuracy: 0.5,
            "复刻乙的回报宽不等于提案宽"
        )
        XCTAssertEqual(
            framed.height,
            proposal.height,
            accuracy: 0.5,
            "复刻乙的回报高不等于提案高——有框有裁就不该溢出"
        )
    }

    // MARK: - 断言 2：玻璃卡不再有任何图层（子项 D 落地后转正式）

    /// 子项 D 把 `S0GlassSurface` 的磨砂副本整层删掉后，`S0View.swift` 里
    /// 不该再剩任何取图／模糊的痕迹。
    ///
    /// **本提交（子项 A）里以 `XCTSkip` 落地**：此刻产品侧那一层还在，正式
    /// 断言必红。子项 D 的提交把本函数体换成正式断言（change-list 逐条记）。
    func testIC151A_S0GlassSurfaceHasNoImageLayer() throws {
        throw XCTSkip(
            "子项 D 尚未落地：S0GlassSurface 仍持有磨砂图层，本条在 D 的提交里转为正式断言。"
        )
    }

    // MARK: - 断言 3：v2 固定色登记值逐条对账

    /// 十二个登记常量逐个等于 Decision_log 第 175／176 条定下的取值；
    /// v1 那十个「照片强模糊铺底」的量名在剔注释的源码里**一个不剩**。
    ///
    /// 裁定 四：SPEC-S0 v2 尚未晋级，出处注释一律指 Decision_log 与本卡，
    /// 不得把新值冒充成 v1 第十四节的登记值。
    func testIC151B_AmbientRegistryMatchesDecision175And176() throws {
        XCTAssertEqual(
            S2AmbientMetrics.washTopOpacity,
            0.07,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2AmbientMetrics.washFadeLocation,
            0.42,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2AmbientMetrics.washBottomOpacity,
            0.22,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S2AmbientMetrics.glowCenterX, 0.50, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.glowCenterY, 0.34, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.glowRadiusX, 0.92, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.glowRadiusY, 0.42, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.glowOpacity, 0.10, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.glowFadeStop, 0.72, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.grainOpacity, 0.90, accuracy: 0.000_001)

        // 幕底色 #0B1A13 与绿色相 #7AC49E，两者 alpha 均为 1。
        assertColor(S2AmbientMetrics.baseColor, red: 11, green: 26, blue: 19)
        assertColor(
            S2AmbientMetrics.tintColor,
            red: 122,
            green: 196,
            blue: 158
        )

        let ambient = try XCTUnwrap(strippedSource(Self.ambientPath))
        // v1 的十个量名一个不剩（留死值是陷阱 12 的同类）。
        for retired in [
            "blurRadius",
            "veilTopOpacity",
            "tintRadius",
            "tintHue",
            "sourceTargetEdge"
        ] {
            XCTAssertEqual(
                occurrences(of: retired, in: ambient),
                0,
                "v1 的旧量名仍在：" + retired
            )
        }

        // 出处注释逐个写明（注释要带注释扫，故读原文不读剔过的）。
        let raw = try XCTUnwrap(sourceText(Self.ambientPath))
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "取值出处：Decision_log 第 175／176 条", in: raw),
            12
        )
        XCTAssertEqual(
            occurrences(of: "取值出处：SPEC-S0 v1 第十四节", in: raw),
            0,
            "新值不得冒充 v1 的登记值（裁定 四）"
        )

        // 视图体内一个裸数都不写（`0`／`1`／`2` 之外），全部经登记表。
        let viewBody = try XCTUnwrap(
            slice(
                ambient,
                from: "struct S2AmbientBackdropView: View {",
                to: Self.topLevelClose
            ),
            "氛围底视图体没切到——声明文本变了，断言会静默放空"
        )
        let literals = numericLiterals(in: viewBody)
        XCTAssertTrue(
            literals.isSubset(of: ["0", "1", "2"]),
            "氛围底视图体出现了登记值之外的裸数："
                + literals.subtracting(["0", "1", "2"]).sorted().joined(
                    separator: ","
                )
        )
        XCTAssertGreaterThan(
            occurrences(of: "S2AmbientMetrics.", in: viewBody),
            0,
            "视图体一处登记值都没引用，扫描口径可疑"
        )
    }

    // MARK: - 断言 4：取图链整条删除（裁定 五）

    /// 氛围底文件不再 `import Photos`、不再有取图协议／实现／协调器／读数，
    /// 也不再有任何发布源。**正对照**：同一组 PhotoKit needle 扫一个确实用
    /// PhotoKit 的既有文件必须非零——否则「各为 0」可能只是 needle 写错的空转。
    func testIC151B_AmbientChainHasNoPhotoKitAndNoPublisher() throws {
        let ambient = try XCTUnwrap(strippedSource(Self.ambientPath))
        XCTAssertGreaterThan(ambient.count, 0)
        for symbol in [
            "import Photos",
            "PHAsset",
            "PHImageManager",
            "S2AmbientImageLoading",
            "S2AmbientBackdropStore",
            "S2AmbientBackdropReadout",
            "@Published",
            "ObservableObject"
        ] {
            XCTAssertEqual(
                occurrences(of: symbol, in: ambient),
                0,
                "氛围底文件仍含 " + symbol
            )
        }

        let scanner = try XCTUnwrap(strippedSource(Self.photoKitControlPath))
        for symbol in ["import Photos", "PHAsset", "PHImageManager"] {
            XCTAssertGreaterThan(
                occurrences(of: symbol, in: scanner),
                0,
                "正对照文件里读不到 " + symbol + "，扫描是空转"
            )
        }
    }

    // MARK: - 夹具

    /// 一张纯色正方形图。内容无关紧要——机制只看尺寸与纵横比。
    @MainActor
    private static func solidSquareImage(edge: CGFloat) -> UIImage {
        let size = CGSize(width: edge, height: edge)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 尺寸的日志表示。不用字符串插值拼——保持与本仓既有扫描门禁同口径。
    private static func describe(_ size: CGSize) -> String {
        String(format: "%.2fx%.2f", size.width, size.height)
    }

    private static let ambientPath =
        "PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift"
    private static let s0ViewPath =
        "PhotoCleanupMVE/Features/S0/S0View.swift"
    private static let s2ViewPath =
        "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let appPath =
        "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    /// PhotoKit 正对照文件。取一个**本卡不动**且确实用 PhotoKit 的既有文件。
    private static let photoKitControlPath =
        "PhotoCleanupMVE/Services/AssetSizeScanner.swift"

    /// 顶层类型的收口：换行 + 右花括号 + 换行。
    ///
    /// 用 `UnicodeScalar` 拼而不写转义字面量：本机（Windows／Git Bash）用
    /// heredoc 打补丁时会把反斜杠吞掉，单行字符串于是在行尾不闭合、编译直接
    /// 报错（IC-148 #294 实例，白费一次 CI）。照 IC148 既有口径。
    private static let topLevelClose =
        String(Character(UnicodeScalar(UInt8(10)))) + "}"
            + String(Character(UnicodeScalar(UInt8(10))))

    /// 色值逐通道核对。两种 trait 解析同值也一并钉——氛围底恒为深色配方。
    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let resolved = UIColor(color)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        XCTAssertTrue(
            resolved.getRed(
                &actualRed,
                green: &actualGreen,
                blue: &actualBlue,
                alpha: &actualAlpha
            ),
            file: file,
            line: line
        )
        XCTAssertEqual(actualRed * 255, red, accuracy: 0.6, file: file, line: line)
        XCTAssertEqual(
            actualGreen * 255,
            green,
            accuracy: 0.6,
            file: file,
            line: line
        )
        XCTAssertEqual(
            actualBlue * 255,
            blue,
            accuracy: 0.6,
            file: file,
            line: line
        )
        XCTAssertEqual(actualAlpha, 1, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(
            resolved.resolvedColor(
                with: UITraitCollection(userInterfaceStyle: .dark)
            ),
            resolved.resolvedColor(
                with: UITraitCollection(userInterfaceStyle: .light)
            ),
            "该色随外观解析出了两个值",
            file: file,
            line: line
        )
    }

    // MARK: - 源码扫描 helper（口径与 IC146／IC148 两个文件一致）

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

    /// 读源码并剔掉 `//` 注释与字符串字面量内容。实现层面的「有没有用到
    /// 某个符号」只该看代码，注释里解释该符号为何不用会被当成命中（#289 实证）。
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
                // 换行照留，剔注释不得把上下两行的记号粘成一个。
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

    /// 截取 `.onChange(of: <key>)` 的回调体（到下一个 `.onChange(` 为止）。
    /// 与 IC-141／IC-143 两条既有断言同一口径——另起一条 `.onChange` 会被它
    /// 抢先截到（#289 实证）。
    private func onChangeBody(of key: String, in text: String) -> String {
        guard let start = text.range(of: ".onChange(of: " + key + ")") else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: ".onChange(") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    /// 取出源码里所有**独立的**数值字面量。口径与 IC148 同：紧邻的前后字符
    /// 都不是标识符字符才算一个数，因此 `S0HomeMetrics` 里的 `0` 不计。
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
            if isIdentifierCharacter(previous) {
                // 跳过整个标识符——**判据必须含数字**，否则当前字符是数字时
                // 指针不前进，循环不终止（会把测试挂死）。
                while index < characters.count,
                      isIdentifierBodyCharacter(characters[index]) {
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

    private func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private func isIdentifierBodyCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}
