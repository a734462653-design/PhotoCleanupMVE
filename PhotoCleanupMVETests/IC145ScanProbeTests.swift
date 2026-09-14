import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-145：扫描服务探针的纯函数测试。
///
/// **本文件只测纯函数**（判据真值表、分档统计、报告文本拼装）。卡内明令
/// 不测 PhotoKit 取数——取数结论由 Lynn 真机跑 H68 后回报，模拟器上没有
/// 真实照片库，任何「模拟器绿」都冒充不了真机结论（纪律 5、陷阱 1）。
final class IC145ScanProbeTests: XCTestCase {

    // MARK: - 断言 1：屏幕录制判据四种 rule 的真值表

    /// `.filename`：只看文件名前缀，且**大小写敏感**。
    func testIC145A_FilenameRuleIsCaseSensitivePrefixOnly() {
        let screen = CGSize(width: 1_179, height: 2_556)
        let offScreen = CGSize(width: 640, height: 480)

        // 前缀命中，分辨率不命中 → 仅文件名判据为真。
        XCTAssertTrue(verdict(
            filename: "RPReplay_Final1699999999.mp4",
            pixels: offScreen,
            screen: screen,
            rule: .filename
        ))
        // 边界：文件名恰为前缀本身（无扩展名、无后缀）。
        XCTAssertTrue(verdict(
            filename: ScreenRecordingHeuristic.filenamePrefix,
            pixels: offScreen,
            screen: screen,
            rule: .filename
        ))
        // 大小写不同 → `.filename`（敏感）不命中。
        XCTAssertFalse(verdict(
            filename: "rpreplay_final1699999999.mp4",
            pixels: offScreen,
            screen: screen,
            rule: .filename
        ))
        // 前缀不在开头 → 不命中。
        XCTAssertFalse(verdict(
            filename: "video_RPReplay_Final.mp4",
            pixels: offScreen,
            screen: screen,
            rule: .filename
        ))
        // 文件名缺失或为空 → 不命中。
        XCTAssertFalse(verdict(
            filename: nil,
            pixels: offScreen,
            screen: screen,
            rule: .filename
        ))
        XCTAssertFalse(verdict(
            filename: "",
            pixels: offScreen,
            screen: screen,
            rule: .filename
        ))

        // 大小写不敏感那一列单独成立——报告里两列都记，判据只用敏感列。
        XCTAssertTrue(ScreenRecordingHeuristic.matchesFilename(
            "rpreplay_final1699999999.mp4",
            caseSensitive: false
        ))
        XCTAssertFalse(ScreenRecordingHeuristic.matchesFilename(
            "rpreplay_final1699999999.mp4",
            caseSensitive: true
        ))
    }

    /// `.resolution`：像素尺寸等于设备原生屏幕像素，**允许宽高互换**；
    /// 屏幕尺寸为零时不得判真。
    func testIC145A_ResolutionRuleAllowsSwapAndRejectsZeroScreen() {
        let screen = CGSize(width: 1_179, height: 2_556)

        // 竖向录制：与屏幕逐边相等。
        XCTAssertTrue(verdict(
            filename: nil,
            pixels: CGSize(width: 1_179, height: 2_556),
            screen: screen,
            rule: .resolution
        ))
        // 横向录制：宽高互换。
        XCTAssertTrue(verdict(
            filename: nil,
            pixels: CGSize(width: 2_556, height: 1_179),
            screen: screen,
            rule: .resolution
        ))
        // 差一个像素即不命中。
        XCTAssertFalse(verdict(
            filename: nil,
            pixels: CGSize(width: 1_178, height: 2_556),
            screen: screen,
            rule: .resolution
        ))
        // 边界：屏幕尺寸为零——不得把 0×0 资产判成命中。
        XCTAssertFalse(verdict(
            filename: nil,
            pixels: .zero,
            screen: .zero,
            rule: .resolution
        ))
        // 边界：屏幕可读但资产像素为零。
        XCTAssertFalse(verdict(
            filename: nil,
            pixels: .zero,
            screen: screen,
            rule: .resolution
        ))
        // 边界：资产像素可读但屏幕读不到。
        XCTAssertFalse(verdict(
            filename: nil,
            pixels: CGSize(width: 1_179, height: 2_556),
            screen: .zero,
            rule: .resolution
        ))
    }

    /// 取或 / 取与：两个基础判据的四种组合逐格核对。
    func testIC145A_CombinedRulesCoverTheFullTruthTable() {
        let screen = CGSize(width: 1_179, height: 2_556)
        let matchingPixels = CGSize(width: 1_179, height: 2_556)
        let otherPixels = CGSize(width: 640, height: 480)
        let matchingName = "RPReplay_Final1699999999.mp4"
        let otherName = "IMG_0001.MOV"

        let cases: [(String?, CGSize, Bool, Bool)] = [
            (matchingName, matchingPixels, true, true),
            (matchingName, otherPixels, true, false),
            (otherName, matchingPixels, true, false),
            (otherName, otherPixels, false, false)
        ]
        for (filename, pixels, expectedOr, expectedAnd) in cases {
            XCTAssertEqual(
                verdict(
                    filename: filename,
                    pixels: pixels,
                    screen: screen,
                    rule: .filenameOrResolution
                ),
                expectedOr,
                "取或判据在 \(filename ?? "nil") / \(pixels) 上不符"
            )
            XCTAssertEqual(
                verdict(
                    filename: filename,
                    pixels: pixels,
                    screen: screen,
                    rule: .filenameAndResolution
                ),
                expectedAnd,
                "取与判据在 \(filename ?? "nil") / \(pixels) 上不符"
            )
        }

        // 测量结构上的 `verdict(for:)` 必须与判据函数同口径。
        for rule in ScreenRecordingRule.allCases {
            XCTAssertEqual(
                makeMeasurement(
                    filename: matchingName,
                    pixelWidth: 1_179,
                    pixelHeight: 2_556
                ).verdict(for: rule),
                verdict(
                    filename: matchingName,
                    pixels: matchingPixels,
                    screen: screen,
                    rule: rule
                ),
                "测量结构与判据函数在 \(rule.rawValue) 上分叉"
            )
        }
    }

    // MARK: - 断言 2：子项 A 报告文本

    func testIC145A_ProbeTextRowHeaderAndSummaryAreDeterministic() {
        XCTAssertEqual(ScreenRecordingProbeText.formatVersion, 1)

        let hit = makeMeasurement(
            assetID: "ABCDEFGH-1234/L0/001",
            filename: "RPReplay_Final1699999999.mp4",
            pixelWidth: 1_179,
            pixelHeight: 2_556,
            durationSeconds: 12.5
        )
        XCTAssertEqual(
            ScreenRecordingProbeText.row(hit),
            "ABCDEFGH|RPReplay_Final1699999999.mp4|1179x2556|12.50|" +
                "2023-11-14T22:13:20Z|name-cs=yes|name-ci=yes|resolution=yes"
        )

        // 文件名取不到 + 分辨率不命中：全 no，文件名列写 none。
        let miss = makeMeasurement(
            assetID: "ZYXWVUTS-9999/L0/001",
            filename: nil,
            pixelWidth: 640,
            pixelHeight: 480,
            durationSeconds: 0
        )
        XCTAssertEqual(
            ScreenRecordingProbeText.row(miss),
            "ZYXWVUTS|none|640x480|0.00|2023-11-14T22:13:20Z|" +
                "name-cs=no|name-ci=no|resolution=no"
        )

        let header = ScreenRecordingProbeText.header(
            videoCount: 2,
            libraryAssetCount: 4_567,
            unresolvedCount: 1,
            screenPixelWidth: 1_179,
            screenPixelHeight: 2_556
        )
        let headerLines = header.components(separatedBy: "\n")
        XCTAssertEqual(headerLines.count, 7)
        XCTAssertEqual(headerLines[1], "format-version=1")
        XCTAssertEqual(
            headerLines[2],
            "columns=" + ScreenRecordingProbeText.columns
        )
        XCTAssertEqual(headerLines[5], "screen-pixels=1179x2556")
        XCTAssertEqual(
            headerLines[6],
            "video-count=2|library-asset-count=4567|unresolved=1"
        )

        // 汇总：一条两判据全中、一条全不中 → 四种判据的命中数逐行核对。
        let summaryLines = ScreenRecordingProbeText
            .summary([hit, miss])
            .components(separatedBy: "\n")
        XCTAssertEqual(summaryLines.count, 8)
        XCTAssertEqual(
            summaryLines[0],
            "summary|rule=filename-only|hits=1/2 (50.0%)"
        )
        XCTAssertEqual(
            summaryLines[1],
            "summary|rule=resolution-only|hits=1/2 (50.0%)"
        )
        XCTAssertEqual(
            summaryLines[2],
            "summary|rule=filename-or-resolution|hits=1/2 (50.0%)"
        )
        XCTAssertEqual(
            summaryLines[3],
            "summary|rule=filename-and-resolution|hits=1/2 (50.0%)"
        )
        XCTAssertEqual(
            summaryLines[4],
            "summary|case-insensitive-filename-hits=1/2"
        )
        XCTAssertEqual(summaryLines[5], "summary|resolution-hit-filename-miss=0")
        XCTAssertEqual(summaryLines[6], "summary|filename-hit-resolution-miss=0")
        XCTAssertEqual(
            summaryLines[7],
            "summary|missing-video-resource-filename=1"
        )
    }

    /// 明细只列两组：任一判据命中的全部行 + 分辨率命中但文件名未命中的全部行。
    /// 后者是误认的主要嫌疑，卡内点名要单列。
    func testIC145A_ReportListsHitsAndResolutionOnlySuspectsSeparately() {
        let nameAndResolution = makeMeasurement(
            assetID: "AAAAAAAA",
            filename: "RPReplay_Final1.mp4",
            pixelWidth: 1_179,
            pixelHeight: 2_556
        )
        // 分辨率命中、文件名未命中——误认嫌疑。
        let resolutionOnly = makeMeasurement(
            assetID: "BBBBBBBB",
            filename: "IMG_0002.MOV",
            pixelWidth: 2_556,
            pixelHeight: 1_179
        )
        let neither = makeMeasurement(
            assetID: "CCCCCCCC",
            filename: "IMG_0003.MOV",
            pixelWidth: 640,
            pixelHeight: 480
        )
        let report = ScreenRecordingProbeText.report(
            measurements: [nameAndResolution, resolutionOnly, neither],
            libraryAssetCount: 100,
            unresolvedCount: 0,
            screenPixelWidth: 1_179,
            screenPixelHeight: 2_556
        )
        let lines = report.components(separatedBy: "\n")

        XCTAssertTrue(lines.contains("[hits] any-rule-matched=2"))
        XCTAssertTrue(
            lines.contains("[resolution-only] suspected-false-positive=1")
        )
        // 两个命中项都在；未命中项一行都不出现。
        XCTAssertEqual(
            lines.filter { $0.hasPrefix("AAAAAAAA|") }.count,
            1
        )
        XCTAssertEqual(
            lines.filter { $0.hasPrefix("BBBBBBBB|") }.count,
            2,
            "分辨率命中且文件名未命中的行应在命中组与嫌疑组各出现一次"
        )
        XCTAssertTrue(
            lines.allSatisfy { !$0.hasPrefix("CCCCCCCC|") },
            "两个判据都不命中的资产不应出现在明细里"
        )
        XCTAssertTrue(
            lines.contains("summary|resolution-hit-filename-miss=1")
        )
    }

    // MARK: - 夹具

    private func verdict(
        filename: String?,
        pixels: CGSize,
        screen: CGSize,
        rule: ScreenRecordingRule
    ) -> Bool {
        ScreenRecordingHeuristic.isScreenRecording(
            filename: filename,
            pixelSize: pixels,
            screenSize: screen,
            rule: rule
        )
    }

    /// 固定创建日期，报告文本才钉得住（`ProbeFormat` 用 UTC + POSIX）。
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeMeasurement(
        assetID: String = "ABCDEFGH-1234/L0/001",
        filename: String?,
        pixelWidth: Int,
        pixelHeight: Int,
        durationSeconds: Double = 1
    ) -> ScreenRecordingMeasurement {
        let screen = CGSize(width: 1_179, height: 2_556)
        let pixels = CGSize(
            width: CGFloat(pixelWidth),
            height: CGFloat(pixelHeight)
        )
        return ScreenRecordingMeasurement(
            assetID: assetID,
            originalFilename: filename,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            durationSeconds: durationSeconds,
            creationDate: fixedDate,
            matchesFilenameCaseSensitive: ScreenRecordingHeuristic
                .matchesFilename(filename, caseSensitive: true),
            matchesFilenameCaseInsensitive: ScreenRecordingHeuristic
                .matchesFilename(filename, caseSensitive: false),
            matchesResolution: ScreenRecordingHeuristic.matchesResolution(
                pixelSize: pixels,
                screenSize: screen
            )
        )
    }
}
