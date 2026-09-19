import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-161：相似照片探针（特征提取耗时／相邻距离与分组／画质评分）。
///
/// **全部断言只测纯函数与源码形状，不调用 Vision、不调用 PhotoKit**——探针的全部指标只能
/// 来自 Lynn 的真机（陷阱 1），CI 只证明能编译、纯函数正确、关闭态零副作用。
/// 断言编号与任务卡一一对应：1～3 属子项 A，4～5 属子项 B，6 属子项 C。
final class IC161SimilarPhotosProbeTests: XCTestCase {

    // MARK: - 断言 1：分位数与外推（子项 A）

    func testIC161A_PercentilesAndExtrapolation() {
        XCTAssertNil(SimilarPhotosProbeMath.percentile([], percent: 50))

        let values: [Double] = [10, 20, 30, 40, 50]
        XCTAssertEqual(
            SimilarPhotosProbeMath.percentile(values, percent: 10) ?? 0,
            10,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            SimilarPhotosProbeMath.percentile(values, percent: 50) ?? 0,
            30,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            SimilarPhotosProbeMath.percentile(values, percent: 90) ?? 0,
            50,
            accuracy: 1e-9
        )
        // 输入乱序结果不变。
        let shuffled: [Double] = [40, 10, 50, 30, 20]
        XCTAssertEqual(
            SimilarPhotosProbeMath.percentile(shuffled, percent: 50) ?? 0,
            30,
            accuracy: 1e-9
        )
        // 单元素：任何分位都是它自己。
        XCTAssertEqual(
            SimilarPhotosProbeMath.percentile([7], percent: 10) ?? 0,
            7,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            SimilarPhotosProbeMath.percentile([7], percent: 90) ?? 0,
            7,
            accuracy: 1e-9
        )

        // 串行上界：(8 + 12) ms × 3500 张 = 70 s。
        XCTAssertEqual(
            SimilarPhotosProbeMath.extrapolatedSerialSeconds(
                meanFetchMilliseconds: 8,
                meanVisionMilliseconds: 12,
                totalCount: 3_500
            ),
            70,
            accuracy: 1e-9
        )
        // 实测吞吐：500 张 ÷ 4 s = 125 张/秒；3500 ÷ 125 = 28 s。
        let throughput = SimilarPhotosProbeMath.throughputPerSecond(
            okCount: 500,
            wallClockSeconds: 4
        )
        XCTAssertEqual(throughput ?? 0, 125, accuracy: 1e-9)
        XCTAssertEqual(
            SimilarPhotosProbeMath.extrapolatedSecondsAtThroughput(
                totalCount: 3_500,
                throughputPerSecond: throughput ?? 0
            ) ?? 0,
            28,
            accuracy: 1e-9
        )
        XCTAssertNil(
            SimilarPhotosProbeMath.extrapolatedSecondsAtThroughput(
                totalCount: 3_500,
                throughputPerSecond: 0
            )
        )
        XCTAssertNil(
            SimilarPhotosProbeMath.throughputPerSecond(okCount: 0, wallClockSeconds: 4)
        )
        XCTAssertNil(
            SimilarPhotosProbeMath.throughputPerSecond(okCount: 5, wallClockSeconds: 0)
        )
    }

    // MARK: - 断言 2：特征报告全 ASCII 且字段齐全（子项 A）

    func testIC161A_ReportTextIsAsciiAndCarriesEveryField() {
        let report = SimilarPhotosFeatureProbeText.report(
            result: Self.sampleFeatureResult(),
            environmentStart: SimilarPhotosEnvironmentSample(
                thermalRawValue: 0,
                batteryPercent: -1,
                availableMemoryBytes: 9_000
            ),
            environmentEnd: SimilarPhotosEnvironmentSample(
                thermalRawValue: 2,
                batteryPercent: 71,
                availableMemoryBytes: 8_000
            )
        )

        XCTAssertTrue(
            report.allSatisfy { $0.isASCII },
            "报告必须全 ASCII，便于复制回来逐字对读"
        )
        for needle in [
            "format=ic161-feature-v1",
            "library_images=",
            "screenshots_excluded=",
            "sampled=",
            "enumerate_ms=",
            "revision=",
            "concurrency=",
            "target_long_side=360",
            "thermal_start=",
            "thermal_end=",
            "battery_start=",
            "battery_end=",
            "mem_available_start=",
            "mem_available_min=",
            "print_element_count=",
            "print_bytes=",
            "fetch_ms p50=",
            "vision_ms p50=",
            "ok=",
            "in_cloud=",
            "failed=",
            "throughput=",
            "extrapolated_serial_s=",
            "extrapolated_at_measured_throughput_s=",
            "extrapolated_print_bytes="
        ] {
            XCTAssertTrue(report.contains(needle), needle)
        }
        // 负电量印 unknown，不印负数。
        XCTAssertTrue(report.contains("battery_start=unknown"))
        XCTAssertTrue(report.contains("battery_end=71"))
        XCTAssertTrue(report.contains("thermal_start=nominal"))
        XCTAssertTrue(report.contains("thermal_end=serious"))
        // 三类结局各一张。
        XCTAssertTrue(report.contains("ok=1"))
        XCTAssertTrue(report.contains("in_cloud=1"))
        XCTAssertTrue(report.contains("failed=1"))
    }

    // MARK: - 断言 3：特征协调器在 run 之前零副作用（子项 A）

    func testIC161A_FeatureCoordinatorIsInertUntilRun() throws {
        let source = try XCTUnwrap(strippedSource(Self.probePath))
        let head = try XCTUnwrap(
            slice(
                source,
                from: "final class SimilarPhotosFeatureProbeCoordinator",
                to: "    func "
            ),
            "协调器切片没切到——类声明或第一个方法的文本变了"
        )
        XCTAssertGreaterThan(head.count, 0)
        for needle in Self.sideEffectNeedles {
            XCTAssertEqual(
                occurrences(of: needle, in: head),
                0,
                "协调器的属性初值区出现了 " + needle
            )
        }

        // 整文件：禁网络、无 `return "字面量"`（硬编码扫描器）、不用 TaskGroup。
        XCTAssertEqual(occurrences(of: "isNetworkAccessAllowed = true", in: source), 0)
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "isNetworkAccessAllowed = false", in: source),
            1
        )
        XCTAssertEqual(occurrences(of: "return " + Self.quote, in: source), 0)
        XCTAssertEqual(occurrences(of: "TaskGroup", in: source), 0)
        // 正对照：上面那几个 0 不是对着空文件数的。
        XCTAssertGreaterThanOrEqual(occurrences(of: "DispatchSemaphore(", in: source), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "func run(", in: source), 1)
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "VNGenerateImageFeaturePrintRequest", in: source),
            1
        )

        let coordinator = SimilarPhotosFeatureProbeCoordinator()
        XCTAssertFalse(coordinator.isRunning)
        XCTAssertTrue(coordinator.reportText.isEmpty)
        XCTAssertTrue(coordinator.progressText.isEmpty)
        XCTAssertTrue(coordinator.sampleAssetIDs.isEmpty)
        XCTAssertFalse(coordinator.canExport)
    }

    // MARK: - 夹具与 helper

    static let probePath = "PhotoCleanupMVE/Services/SimilarPhotosProbe.swift"

    /// 关闭态零副作用的 needle 名单：构造期不许碰相册、Vision、通知中心、偏好与文件系统。
    static let sideEffectNeedles = [
        "PHPhotoLibrary",
        "PHAsset",
        "PHImageManager",
        "VNGenerate",
        "VNCalculate",
        "NotificationCenter",
        "UserDefaults",
        "FileManager"
    ]

    /// 双引号本身。写成变量是为了让 needle `return "` 不以字面量形式出现在本文件里。
    static let quote = String(Character(UnicodeScalar(UInt8(34))))

    static let newline = String(Character(UnicodeScalar(UInt8(10))))

    static func sampleFeatureResult() -> SimilarPhotosFeatureProbeResult {
        SimilarPhotosFeatureProbeResult(
            libraryImageCount: 6_000,
            screenshotCount: 2_500,
            sampledCount: 3,
            enumerateMilliseconds: 12.5,
            revision: 1,
            concurrency: 2,
            measurements: [
                SimilarPhotosFeatureMeasurement(
                    fetchMilliseconds: 8,
                    visionMilliseconds: 12,
                    outcome: .ok
                ),
                SimilarPhotosFeatureMeasurement(
                    fetchMilliseconds: 5,
                    visionMilliseconds: 0,
                    outcome: .inCloud
                ),
                SimilarPhotosFeatureMeasurement(
                    fetchMilliseconds: 4,
                    visionMilliseconds: 3,
                    outcome: .failed
                )
            ],
            printElementCount: 768,
            printElementTypeRawValue: 1,
            printByteCount: 3_072,
            wallClockSeconds: 4,
            memoryMinimumBytes: 7_500,
            cancelled: false
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
