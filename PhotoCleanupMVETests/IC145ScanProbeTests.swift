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

    // MARK: - 断言 3：分位数统计

    /// 最近秩法：升序后取第 `ceil(rank / 100 × n)` 个，秩从 1 起、夹逼到 `[1, n]`，
    /// 偶数长度**不插值**。报告头部的 `percentile-note` 写的就是这条口径。
    func testIC145B_PercentileUsesNearestRankAndHandlesEdgeCases() {
        // 空数组 → nil。
        XCTAssertNil(ProbeStatistics.percentile([], 50))
        XCTAssertNil(ProbeStatistics.percentile([], 95))

        // 单元素：任何分位都回它自己。
        XCTAssertEqual(ProbeStatistics.percentile([7], 50), 7)
        XCTAssertEqual(ProbeStatistics.percentile([7], 95), 7)
        XCTAssertEqual(ProbeStatistics.percentile([7], 0), 7)

        // 偶数长度：不插值，p50 取第 ceil(0.5 × 4) = 2 个 → 2。
        XCTAssertEqual(ProbeStatistics.percentile([1, 2, 3, 4], 50), 2)
        XCTAssertEqual(ProbeStatistics.percentile([4, 3, 2, 1], 50), 2)
        // p95 取第 ceil(0.95 × 4) = 4 个 → 4。
        XCTAssertEqual(ProbeStatistics.percentile([1, 2, 3, 4], 95), 4)

        // 奇数长度：p50 取第 ceil(0.5 × 5) = 3 个 → 3。
        XCTAssertEqual(ProbeStatistics.percentile([5, 3, 1, 4, 2], 50), 3)

        // 100 条：p50 取第 50 个，p95 取第 95 个。
        let hundred = (1...100).map(Double.init)
        XCTAssertEqual(ProbeStatistics.percentile(hundred, 50), 50)
        XCTAssertEqual(ProbeStatistics.percentile(hundred, 95), 95)
        XCTAssertEqual(ProbeStatistics.percentile(hundred.shuffled(), 95), 95)
    }

    /// 分层抽样：三族各至多 70，轮转交错后截断到 200。
    func testIC145B_StratifiedSampleCapsPerKindAndTotal() {
        let photo = (0..<500).map { "P\($0)" }
        let live = (0..<500).map { "L\($0)" }
        let video = (0..<500).map { "V\($0)" }

        let sample = ByteRouteSampling.stratifiedSample(
            photo: photo,
            livePhoto: live,
            video: video
        )
        XCTAssertEqual(sample.count, ByteRouteSampling.sampleLimit)
        for prefix in ["P", "L", "V"] {
            let count = sample.filter { $0.hasPrefix(prefix) }.count
            XCTAssertLessThanOrEqual(count, ByteRouteSampling.perKindLimit)
            XCTAssertGreaterThanOrEqual(
                count,
                60,
                "轮转交错后 \(prefix) 族被削得过多：\(count)"
            )
        }
        XCTAssertEqual(Set(sample).count, sample.count, "样本不得重复")

        // 某族为空时不报错，其余两族照取。
        let twoKinds = ByteRouteSampling.stratifiedSample(
            photo: photo,
            livePhoto: [],
            video: video
        )
        XCTAssertEqual(
            twoKinds.count,
            ByteRouteSampling.perKindLimit * 2,
            "两族各满 70 条、交错后 140 条，未达 200 上限即不截断"
        )
        XCTAssertTrue(twoKinds.allSatisfy { !$0.hasPrefix("L") })

        // 全空 → 空样本。
        XCTAssertTrue(
            ByteRouteSampling
                .stratifiedSample(photo: [], livePhoto: [], video: [])
                .isEmpty
        )
    }

    // MARK: - 断言 4：子项 B 报告文本

    func testIC145B_ProbeTextRowAndRouteSummaryAreDeterministic() {
        XCTAssertEqual(ByteRouteProbeText.formatVersion, 1)

        let agreeing = makeByteRouteMeasurement()
        XCTAssertEqual(
            ByteRouteProbeText.row(agreeing),
            "ABCDEFGH|photo|edited=no|enum=0.500ms|data-bytes=1000|" +
                "data=12.250ms|url-bytes=1000|url=2.500ms|prop-bytes=1000|" +
                "prop=0.125ms"
        )

        let routeLines = ByteRouteProbeText.routeSummary([agreeing])
        XCTAssertEqual(routeLines.count, 3)
        XCTAssertEqual(
            routeLines[0],
            "summary|route=data|p50=12.250ms|p95=12.250ms|max=12.250ms|" +
                "ok=1/1 (100.0%)"
        )
        XCTAssertEqual(
            routeLines[1],
            "summary|route=url|p50=2.500ms|p95=2.500ms|max=2.500ms|" +
                "ok=1/1 (100.0%)"
        )
        XCTAssertEqual(
            routeLines[2],
            "summary|route=resource-property|p50=0.125ms|p95=0.125ms|" +
                "max=0.125ms|ok=1/1 (100.0%)"
        )

        // 失败计入分母：途径 3 取不到时 ok 变 0/1，耗时读数照样入统计。
        let propertyFailed = makeByteRouteMeasurement(
            resourcePropertyByteCount: nil
        )
        XCTAssertEqual(
            ByteRouteProbeText.routeSummary([propertyFailed])[2],
            "summary|route=resource-property|p50=0.125ms|p95=0.125ms|" +
                "max=0.125ms|ok=0/1 (0.0%)"
        )

        // 键探测行：公开正对照与非公开候选键各一行。
        XCTAssertEqual(
            ByteRouteProbeText.keyProbeLine(ResourceKeyProbeResult(
                key: ResourcePropertyRoute.candidateKey,
                isPublicInterface: false,
                respondsToSelector: true,
                valueTypeName: "__NSCFNumber"
            )),
            "key-probe|key=\(ResourcePropertyRoute.candidateKey)|" +
                "public-interface=no|responds=yes|value-type=__NSCFNumber"
        )
        // 库里没有可供探测的资源时写 unknown，不冒充结论。
        XCTAssertEqual(
            ByteRouteProbeText.keyProbeLine(ResourceKeyProbeResult(
                key: ResourcePropertyRoute.publicControlKey,
                isPublicInterface: true,
                respondsToSelector: nil,
                valueTypeName: nil
            )),
            "key-probe|key=\(ResourcePropertyRoute.publicControlKey)|" +
                "public-interface=yes|responds=unknown|value-type=none"
        )

        // 外推行：p50 × 全库数，毫秒转秒，且原样标注上界假设。
        let extrapolation = ByteRouteProbeText.extrapolationLines(
            [agreeing],
            libraryAssetCount: 1_000
        )
        XCTAssertEqual(extrapolation.count, 3)
        XCTAssertEqual(
            extrapolation[0],
            "extrapolation|route=data|p50-times-library=12.25s|" +
                "assumes serial, no cache, no concurrency (upper bound)"
        )
    }

    /// 不一致明细**只在确有差值时出现**。
    func testIC145B_MismatchLinesAppearOnlyWhenBytesActuallyDiffer() {
        let agreeing = makeByteRouteMeasurement()
        XCTAssertTrue(ByteRouteProbeText.mismatchLines([agreeing]).isEmpty)
        XCTAssertFalse(agreeing.hasByteMismatch)

        // 一条途径失败（nil）不算不一致——没有可比性，不该进明细。
        let partiallyFailed = makeByteRouteMeasurement(
            resourcePropertyByteCount: nil
        )
        XCTAssertTrue(
            ByteRouteProbeText.mismatchLines([partiallyFailed]).isEmpty
        )
        XCTAssertFalse(partiallyFailed.hasByteMismatch)

        // 三条全失败也不算不一致。
        let allFailed = makeByteRouteMeasurement(
            dataByteCount: nil,
            urlByteCount: nil,
            resourcePropertyByteCount: nil
        )
        XCTAssertTrue(ByteRouteProbeText.mismatchLines([allFailed]).isEmpty)

        // 确有差值：两两差值逐列给出，取不到的对写 none。
        let mismatched = makeByteRouteMeasurement(
            assetID: "ZYXWVUTS-9999/L0/001",
            mediaKind: .video,
            isEdited: true,
            urlByteCount: 900,
            resourcePropertyByteCount: nil
        )
        XCTAssertTrue(mismatched.hasByteMismatch)
        let lines = ByteRouteProbeText.mismatchLines([agreeing, mismatched])
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(
            lines[0],
            "mismatch|ZYXWVUTS|video|edited=yes|data=1000|url=900|" +
                "resource-property=none|data-url=100|" +
                "data-resource-property=none|url-resource-property=none"
        )

        // 报告体：全一致时不出 [mismatch] 段；有差值时出，且计数正确。
        let clean = ByteRouteProbeText.report(
            measurements: [agreeing],
            libraryAssetCount: 10,
            limit: ByteRouteSampling.sampleLimit,
            perKindLimit: ByteRouteSampling.perKindLimit,
            keyProbeResults: []
        )
        XCTAssertFalse(clean.contains("[mismatch]"))
        let dirty = ByteRouteProbeText.report(
            measurements: [agreeing, mismatched],
            libraryAssetCount: 10,
            limit: ByteRouteSampling.sampleLimit,
            perKindLimit: ByteRouteSampling.perKindLimit,
            keyProbeResults: []
        )
        XCTAssertTrue(
            dirty.components(separatedBy: "\n").contains("[mismatch] assets=1")
        )
        XCTAssertTrue(
            dirty.contains("summary|byte-mismatch-assets=1/2")
        )
    }

    // MARK: - 断言 5：途径 3 的键名与 KVC 调用不得外泄

    /// 途径 3 用的是**非公开**运行时键。卡内授权只在探针文件内使用，
    /// 故键名字面量与 `value(forKey:)` 调用在产品路径里命中数必须为 0。
    ///
    /// 扫的是**带引号的键名字面量**：`AssetSizeScanner.swift` 里的
    /// `.fileSizeKey` 是 `URLResourceKey` 成员、不带引号，不该被误判。
    func testIC145B_ResourcePropertyKeyAndKVCStayInsideTheProbeFile() throws {
        let quotedKey = "\"" + ResourcePropertyRoute.candidateKey + "\""
        let kvcCall = "value(forKey:"

        // 正对照：探针文件内两者都在。
        let probeSource = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Services/ScanServiceProbe.swift")
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: quotedKey, in: probeSource),
            1
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: kvcCall, in: probeSource),
            1
        )

        // 负对照：卡内点名的产品路径零命中。
        let scannerPath = "PhotoCleanupMVE/Services/AssetSizeScanner.swift"
        let scannerSource = try XCTUnwrap(sourceText(scannerPath))
        var scanned: [(String, String)] = [(scannerPath, scannerSource)]
        let productURLs =
            productSwiftFileURLs(under: "PhotoCleanupMVE/Features") +
            productSwiftFileURLs(under: "PhotoCleanupMVE/App")
        for url in productURLs {
            let text = try XCTUnwrap(
                try? String(contentsOf: url, encoding: .utf8)
            )
            scanned.append((url.lastPathComponent, text))
        }
        XCTAssertGreaterThan(
            scanned.count,
            3,
            "扫描清单太短，说明路径拼错了，负对照会假通过"
        )

        for (label, source) in scanned {
            XCTAssertEqual(
                occurrences(of: quotedKey, in: source),
                0,
                "途径 3 的键名字面量外泄到 \(label)"
            )
            XCTAssertEqual(
                occurrences(of: kvcCall, in: source),
                0,
                "KVC 调用外泄到 \(label)"
            )
        }

        // 键名本身仍标注为非公开，公开正对照标注为公开。
        XCTAssertFalse(
            ResourcePropertyRoute
                .isPublicInterface(ResourcePropertyRoute.candidateKey)
        )
        XCTAssertTrue(
            ResourcePropertyRoute
                .isPublicInterface(ResourcePropertyRoute.publicControlKey)
        )
    }

    // MARK: - 断言 6：分档函数的边界归属

    /// 时长分档是**半开区间 `[下界, 上界)`**：恰 30 s 归 `30s-2min`、
    /// 恰 120 s 归 `2min-10min`、恰 600 s 归 `gte-10min`。
    /// 报告头部的 `duration-buckets` 写的就是这条口径。
    func testIC145C_DurationBucketBoundariesAreHalfOpen() {
        let cases: [(Double, VideoDurationBucket)] = [
            (0, .underThirtySeconds),
            (29.999, .underThirtySeconds),
            (30, .thirtySecondsToTwoMinutes),
            (119.999, .thirtySecondsToTwoMinutes),
            (120, .twoToTenMinutes),
            (599.999, .twoToTenMinutes),
            (600, .overTenMinutes),
            (3_600, .overTenMinutes)
        ]
        for (seconds, expected) in cases {
            XCTAssertEqual(
                VideoDurationBucket.bucket(forSeconds: seconds),
                expected,
                "\(seconds) s 归档不符"
            )
        }
        XCTAssertEqual(VideoDurationBucket.allCases.count, 4)
    }

    /// 像素分档按**长边**，同样半开区间。
    func testIC145C_PixelBucketBoundariesAreHalfOpenOnTheLongEdge() {
        let cases: [(Int, VideoPixelBucket)] = [
            (0, .belowHD),
            (1_279, .belowHD),
            (1_280, .hd),
            (1_919, .hd),
            (1_920, .fullHD),
            (2_559, .fullHD),
            (2_560, .ultraHD),
            (3_840, .ultraHD)
        ]
        for (pixels, expected) in cases {
            XCTAssertEqual(
                VideoPixelBucket.bucket(forLongEdge: pixels),
                expected,
                "\(pixels) px 归档不符"
            )
        }
        XCTAssertEqual(VideoPixelBucket.allCases.count, 4)
    }

    // MARK: - 断言 7：子项 C 报告文本

    func testIC145C_ProbeTextHeaderDistributionAndFeasibility() {
        XCTAssertEqual(CategoryMetadataProbeText.formatVersion, 1)

        let pass = makeCategoryMetadataPass()
        XCTAssertEqual(pass.averageMicrosecondsPerAsset, 250)

        let headerLines = CategoryMetadataProbeText
            .header(pass)
            .components(separatedBy: "\n")
        XCTAssertEqual(headerLines.count, 7)
        XCTAssertEqual(headerLines[0], "IC-145 C category-metadata probe")
        XCTAssertEqual(headerLines[1], "format-version=1")
        XCTAssertEqual(
            headerLines[6],
            "library-asset-count=1000|pass1=250.000ms"
        )

        let distribution = CategoryMetadataProbeText.distributionLines(pass)
        XCTAssertEqual(distribution.count, 4)
        XCTAssertEqual(
            distribution[0],
            "distribution|photo=900|video=100|screenshot=120|live=80"
        )
        XCTAssertEqual(
            distribution[1],
            "distribution|favorite=30|editable=995|created-within-30d=40"
        )
        XCTAssertEqual(
            distribution[2],
            "distribution|video-duration|lt-30s=60|30s-2min=25|" +
                "2min-10min=10|gte-10min=5"
        )
        XCTAssertEqual(
            distribution[3],
            "distribution|video-long-edge|lt-1280=5|1280-1919=10|" +
                "1920-2559=70|gte-2560=15"
        )

        // 已编辑是**另一遍**的读数，与 editable 分列，并带自己的耗时。
        XCTAssertEqual(
            CategoryMetadataProbeText.editedLine(
                CategoryMetadataEditedPass(
                    editedCount: 12,
                    elapsedMilliseconds: 4_000
                ),
                totalAssetCount: pass.totalAssetCount
            ),
            "distribution|edited-adjustmentData=12/1000|pass2=4000.000ms"
        )

        // 可行性行：有参照值时给比值。
        XCTAssertEqual(
            CategoryMetadataProbeText.feasibilityLine(
                pass,
                byteRouteDataP50Milliseconds: 45
            ),
            "feasibility|metadata-per-asset=250.000us|" +
                "metadata-pass-total=250.000ms|byte-route-data-p50=45.000ms|" +
                "ratio-byte-route-over-metadata=180.0x"
        )
        // 子项 B 本次未跑 → 如实写 none，不拿旧数凑。
        XCTAssertEqual(
            CategoryMetadataProbeText.feasibilityLine(
                pass,
                byteRouteDataP50Milliseconds: nil
            ),
            "feasibility|metadata-per-asset=250.000us|" +
                "metadata-pass-total=250.000ms|byte-route-data-p50=none|" +
                "ratio-byte-route-over-metadata=none"
        )
    }

    /// 空库与空分档：平均耗时回 nil，分档行全写 0，不崩、不留空列。
    func testIC145C_EmptyLibraryAndEmptyBucketsDegradeCleanly() {
        let empty = CategoryMetadataPass(
            totalAssetCount: 0,
            elapsedMilliseconds: 0,
            photoCount: 0,
            videoCount: 0,
            screenshotCount: 0,
            livePhotoCount: 0,
            favoriteCount: 0,
            editableCount: 0,
            recentThirtyDayCount: 0,
            durationBuckets: [:],
            pixelBuckets: [:]
        )
        XCTAssertNil(empty.averageMicrosecondsPerAsset)

        let distribution = CategoryMetadataProbeText.distributionLines(empty)
        XCTAssertEqual(
            distribution[2],
            "distribution|video-duration|lt-30s=0|30s-2min=0|" +
                "2min-10min=0|gte-10min=0"
        )
        XCTAssertEqual(
            distribution[3],
            "distribution|video-long-edge|lt-1280=0|1280-1919=0|" +
                "1920-2559=0|gte-2560=0"
        )
        XCTAssertEqual(
            CategoryMetadataProbeText.feasibilityLine(
                empty,
                byteRouteDataP50Milliseconds: 45
            ),
            "feasibility|metadata-per-asset=none|metadata-pass-total=0.000ms|" +
                "byte-route-data-p50=45.000ms|" +
                "ratio-byte-route-over-metadata=none"
        )

        // 报告体：四段齐全，顺序固定。
        let report = CategoryMetadataProbeText.report(
            pass: makeCategoryMetadataPass(),
            edited: CategoryMetadataEditedPass(
                editedCount: 12,
                elapsedMilliseconds: 4_000
            ),
            byteRouteDataP50Milliseconds: 45
        )
        let lines = report.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 7 + 4 + 1 + 1)
        XCTAssertTrue(lines[11].hasPrefix("distribution|edited-adjustmentData="))
        XCTAssertTrue(lines[12].hasPrefix("feasibility|"))
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

    /// 子项 B 的测量夹具。耗时值都取二进制可精确表示的数（0.5 / 2.5 /
    /// 12.25 / 0.125），报告里的 `%.3f` 舍入才没有歧义。
    private func makeByteRouteMeasurement(
        assetID: String = "ABCDEFGH-1234/L0/001",
        mediaKind: S2AssetSizeProbeMediaKind = .photo,
        isEdited: Bool = false,
        dataByteCount: Int64? = 1_000,
        urlByteCount: Int64? = 1_000,
        resourcePropertyByteCount: Int64? = 1_000
    ) -> ByteRouteMeasurement {
        ByteRouteMeasurement(
            assetID: assetID,
            mediaKind: mediaKind,
            isEdited: isEdited,
            resourceEnumerationElapsedMilliseconds: 0.5,
            dataByteCount: dataByteCount,
            dataElapsedMilliseconds: 12.25,
            urlByteCount: urlByteCount,
            urlElapsedMilliseconds: 2.5,
            resourcePropertyByteCount: resourcePropertyByteCount,
            resourcePropertyElapsedMilliseconds: 0.125
        )
    }

    /// 子项 C 的第一遍读数夹具。1000 条 / 250 ms → 平均 250 us，
    /// 都是二进制可精确表示的数，报告里的舍入没有歧义。
    private func makeCategoryMetadataPass() -> CategoryMetadataPass {
        CategoryMetadataPass(
            totalAssetCount: 1_000,
            elapsedMilliseconds: 250,
            photoCount: 900,
            videoCount: 100,
            screenshotCount: 120,
            livePhotoCount: 80,
            favoriteCount: 30,
            editableCount: 995,
            recentThirtyDayCount: 40,
            durationBuckets: [
                .underThirtySeconds: 60,
                .thirtySecondsToTwoMinutes: 25,
                .twoToTenMinutes: 10,
                .overTenMinutes: 5
            ],
            pixelBuckets: [
                .belowHD: 5,
                .hd: 10,
                .fullHD: 70,
                .ultraHD: 15
            ]
        )
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

    private func productSwiftFileURLs(under relativeDirectory: String) -> [URL] {
        let directory = repoRoot().appendingPathComponent(relativeDirectory)
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return []
        }
        var urls: [URL] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
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
