import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-143：视频页三处修正 + 「有声」接音频会话。
///
/// **本卡只做视频页**：`S2LivePhotoPlayback.swift` 零改动。
/// 断言 1～3、11～13 是登记值／口径／源码扫描断言；断言 4～10 里凡走分页器
/// 与手势的都是夹具驱动，与真机事件序列不同源（陷阱 1），真机落点由 H66 五项兜底。
final class IC143VideoPolishTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    // MARK: - 断言 1：登记值（带正对照）

    func testIC143A_VideoBarMetricsTakeTheNewRegisteredValues() {
        XCTAssertEqual(
            S2MediaMetrics.videoBarHorizontalMargin,
            S2OverlayLayout.chromeHorizontalMargin * 2
        )
        XCTAssertEqual(S2MediaMetrics.videoBarButtonIconPointSize, 20)
        XCTAssertEqual(S2MediaMetrics.videoBarMuteIconPointSize, 22)
        XCTAssertEqual(
            S2MediaMetrics.videoBarButtonHitWidth,
            S2OverlayLayout.minimumTouchTarget
        )

        // 不变量：带高与底缘锚是 H65 第 10 项已过的量，本卡不许动。
        XCTAssertEqual(S2MediaMetrics.videoBarHeight, 44)
        XCTAssertEqual(
            S2MediaMetrics.videoBarBottomToStripTop,
            S2OverlayLayout.stripToBottomRowSpacing
        )

        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }
        let block = mediaMetricsBlock(in: text)
        XCTAssertFalse(block.isEmpty, "未截取到媒体常量容器")
        for symbol in [
            "videoBarHorizontalMargin",
            "videoBarButtonIconPointSize",
            "videoBarMuteIconPointSize",
            "videoBarButtonHitWidth"
        ] {
            XCTAssertEqual(
                occurrences(of: symbol, in: block),
                1,
                "\(symbol) 在容器里不是恰一处定义"
            )
        }

        // 边距与命中区宽都引用登记值，定义里不出现 16／32／44 的裸数；
        // 正对照：带高的定义就是裸数 44。
        let marginDefinition = definition(
            of: "videoBarHorizontalMargin",
            in: block
        )
        XCTAssertTrue(
            marginDefinition.contains("chromeHorizontalMargin"),
            "边距未引用 chrome 既有横向边距"
        )
        for bare in ["16", "32"] {
            XCTAssertFalse(
                marginDefinition.contains(bare),
                "边距定义写了裸数 \(bare)"
            )
        }
        let hitWidthDefinition = definition(
            of: "videoBarButtonHitWidth",
            in: block
        )
        XCTAssertTrue(
            hitWidthDefinition.contains("minimumTouchTarget"),
            "命中区宽未引用最小触控边长"
        )
        XCTAssertFalse(
            hitWidthDefinition.contains("44"),
            "命中区宽写了裸数 44"
        )
        XCTAssertTrue(
            definition(of: "videoBarHeight", in: block).contains("44"),
            "正对照失效：带高本就该是裸数 44"
        )
    }

    // MARK: - 断言 2：两键定宽，轨不吃两键的宽（源码扫描）

    func testIC143A_BothBarButtonsTakeAFixedHitWidthAndTheTrackDoesNot() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        for name in ["playPauseButton", "muteButton"] {
            let body = functionBody(of: name, in: text)
            XCTAssertFalse(body.isEmpty, "未截取到 \(name) 函数体")
            XCTAssertEqual(
                occurrences(
                    of: "width: S2MediaMetrics.videoBarButtonHitWidth",
                    in: body
                ),
                1,
                "\(name) 的命中区未定宽"
            )
            XCTAssertEqual(
                occurrences(of: ".contentShape(Rectangle())", in: body),
                1,
                "\(name) 丢了命中形状"
            )
            XCTAssertEqual(
                occurrences(
                    of: "height: S2MediaMetrics.videoBarHeight",
                    in: body
                ),
                1,
                "\(name) 的命中区高不再取浮框带高"
            )
        }

        let track = functionBody(of: "progressTrack", in: text)
        XCTAssertFalse(track.isEmpty, "未截取到 progressTrack 函数体")
        XCTAssertEqual(
            occurrences(of: "videoBarButtonHitWidth", in: track),
            0,
            "进度轨吃掉了两键的宽"
        )
        // 轨仍是可拖区，起手位移不变（H65 第 4 项已过，本卡不动）。
        XCTAssertEqual(
            occurrences(of: "videoBarScrubMinimumDistance", in: track),
            1
        )
    }

    // MARK: - 夹具

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// 截取 `S2MediaMetrics` 容器正文（与 IC-139 夹具同形）。
    private func mediaMetricsBlock(in text: String) -> String {
        guard let start = text.range(of: "enum S2MediaMetrics {") else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n}\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    /// 截取某个 `static let` 的定义（含续行，到下一个非续行为止）。
    private func definition(of symbol: String, in block: String) -> String {
        let lines = block.components(separatedBy: "\n")
        guard let index = lines.firstIndex(
            where: { $0.contains("static let " + symbol) }
        ) else {
            return ""
        }
        var collected = lines[index]
        var cursor = index + 1
        while cursor < lines.count {
            let line = lines[cursor]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(".") || trimmed.hasPrefix("?") else {
                break
            }
            collected += "\n" + line
            cursor += 1
        }
        return collected
    }

    /// 截取某个 `private func` 的函数体（到同缩进的收口括号为止）。
    private func functionBody(of name: String, in text: String) -> String {
        guard let start = text.range(of: "private func " + name) else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n    }\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("预期值不应为空", file: file, line: line)
            fatalError("测试无法继续")
        }
        return value
    }
}
