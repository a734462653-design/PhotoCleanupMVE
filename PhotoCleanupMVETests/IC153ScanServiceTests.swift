import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-153：批次 5.1 扫描服务——全库增量扫描、持久缓存、三个元数据类别，替换 S0
/// 数据源桩。
///
/// 依据 SPEC-S0 v2（SHA-256 `8A8E…6F44`）第二节第 2／3 部分、第三节 S0-1、
/// 第十二节第 4 条，与任务卡 IC-20260916-153 的六条裁定。断言编号与任务卡一一
/// 对应：1～3 属子项 A，4～7 属子项 B，8～12 属子项 C，13 属子项 D。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：夹具源不是 PhotoKit。首扫耗时、iCloud
/// 取不到字节的比例、屏幕录制的漏认率、前台恢复的观感只有 H75 能判。
final class IC153ScanServiceTests: XCTestCase {

    // MARK: - 断言 1：单资产命中集合与去重归属（子项 A）

    func testIC153A_ClassifierHitsAndPriority() {
        let megabyte: Int64 = 1_000_000
        let threshold = S0ScanRules.bigVideoMinimumByteCount
        // G874：裁定 一（④ Lynn 2026-09-16），执行端不得改动。
        XCTAssertEqual(threshold, 100_000_000)
        XCTAssertEqual(
            S0ScanClassifier.attributionPriority,
            [.bigVideo, .screenRecording, .screenshot]
        )

        // 普通照片：不属任何类别。
        assertClassification(
            scannedAsset("plain-photo", mediaType: .photo, byteCount: 4 * megabyte),
            hits: [],
            primary: nil
        )
        // 截图：像素恰是录屏登记尺寸，但它是照片——不得命中录屏。
        assertClassification(
            scannedAsset(
                "screenshot",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 2 * megabyte
            ),
            hits: [.screenshot],
            primary: .screenshot
        )
        // 小视频。
        assertClassification(
            scannedAsset(
                "small-video",
                mediaType: .video,
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                videoFilename: "IMG_0001.MOV",
                byteCount: 20 * megabyte
            ),
            hits: [],
            primary: nil
        )
        // 不低于门槛的普通视频。
        assertClassification(
            scannedAsset(
                "big-video",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0002.MOV",
                byteCount: 150 * megabyte
            ),
            hits: [.bigVideo],
            primary: .bigVideo
        )
        // 不低于门槛且文件名前缀命中的录屏：两个类别都命中，去重归大视频。
        assertClassification(
            scannedAsset(
                "prefix-recording",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                byteCount: 120 * megabyte
            ),
            hits: [.bigVideo, .screenRecording],
            primary: .bigVideo
        )
        // 像素 2622×1206（横放）且文件名不命中的录屏。
        assertClassification(
            scannedAsset(
                "resolution-recording",
                mediaType: .video,
                pixelWidth: 2_622,
                pixelHeight: 1_206,
                videoFilename: "IMG_0003.MP4",
                byteCount: 30 * megabyte
            ),
            hits: [.screenRecording],
            primary: .screenRecording
        )
        // 未解析的大视频：证据齐全也不命中任何类别。
        assertClassification(
            scannedAsset(
                "unresolved-video",
                mediaType: .video,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                videoFilename: "ScreenRecording_09-01-2025 08-00-00_1.mp4",
                byteCount: threshold,
                isUnresolved: true
            ),
            hits: [],
            primary: nil
        )
        // 前缀判据大小写敏感：小写前缀不命中。
        assertClassification(
            scannedAsset(
                "lowercase-prefix",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "screenrecording_10-13-2025 15-42-39_1.mp4",
                byteCount: 10 * megabyte
            ),
            hits: [],
            primary: nil
        )
        // 门槛恰好相等时命中（大于等于）。
        assertClassification(
            scannedAsset(
                "at-threshold",
                mediaType: .video,
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                videoFilename: "IMG_0004.MOV",
                byteCount: threshold
            ),
            hits: [.bigVideo],
            primary: .bigVideo
        )
        // 差一个字节不命中。
        assertClassification(
            scannedAsset(
                "below-threshold",
                mediaType: .video,
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                videoFilename: "IMG_0005.MOV",
                byteCount: threshold - 1
            ),
            hits: [],
            primary: nil
        )

        // 两条录屏证据分开记（缓存只存这两个布尔）。
        XCTAssertEqual(
            S0ScanClassifier.screenRecordingEvidence(
                mediaType: .video,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                pixelWidth: 886,
                pixelHeight: 1_920
            ),
            S0ScreenRecordingEvidence(filenamePrefixMatched: true, resolutionMatched: false)
        )
        XCTAssertEqual(
            S0ScanClassifier.screenRecordingEvidence(
                mediaType: .video,
                videoFilename: nil,
                pixelWidth: 1_206,
                pixelHeight: 2_622
            ),
            S0ScreenRecordingEvidence(filenamePrefixMatched: false, resolutionMatched: true)
        )
        XCTAssertEqual(
            S0ScanClassifier.screenRecordingEvidence(
                mediaType: .photo,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                pixelWidth: 1_206,
                pixelHeight: 2_622
            ),
            S0ScreenRecordingEvidence(filenamePrefixMatched: false, resolutionMatched: false)
        )

        // 优先序：三个都中取大视频，后两个中取录屏，只中截图取截图。
        XCTAssertEqual(
            S0ScanClassifier.primaryCategory(for: [.screenshot, .screenRecording, .bigVideo]),
            .bigVideo
        )
        XCTAssertEqual(
            S0ScanClassifier.primaryCategory(for: [.screenshot, .screenRecording]),
            .screenRecording
        )
        XCTAssertNil(S0ScanClassifier.primaryCategory(for: []))
        // 本卡不识别的两个类别不参与归属（裁定 二）。
        XCTAssertNil(S0ScanClassifier.primaryCategory(for: [.duplicate, .similar]))
    }

    // MARK: - 断言 2：hero 去重、类别全量（子项 A）

    func testIC153A_AggregationDedupesHeroButNotCategories() {
        let megabyte: Int64 = 1_000_000
        let recording = scannedAsset(
            "recording",
            mediaType: .video,
            pixelWidth: 886,
            pixelHeight: 1_920,
            videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
            byteCount: 150 * megabyte
        )
        let screenshot = scannedAsset(
            "screenshot",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 3 * megabyte
        )
        let plainPhoto = scannedAsset("plain-photo", mediaType: .photo, byteCount: 4 * megabyte)
        let pendingScreenshot = scannedAsset(
            "pending-screenshot",
            mediaType: .photo,
            isScreenshot: true,
            byteCount: 2 * megabyte
        )
        let ledgerVideo = scannedAsset(
            "ledger-video",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            videoFilename: "IMG_0009.MOV",
            byteCount: 200 * megabyte
        )
        let unresolvedVideo = scannedAsset(
            "unresolved-video",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            videoFilename: "IMG_0010.MOV",
            byteCount: 0,
            isUnresolved: true
        )
        let assets: [S0ClassifiedAsset] = [
            recording,
            screenshot,
            plainPhoto,
            pendingScreenshot,
            ledgerVideo,
            unresolvedVideo
        ].map { S0ScanClassifier.classified($0) }

        let ledgerEntry = S0LedgerEntry(
            categoryID: .bigVideo,
            byteCount: 200 * megabyte,
            committedAt: Date(timeIntervalSince1970: 1_789_344_000),
            availableCapacityBaseline: 6_000_000_000
        )
        let context = S0ScanAggregationContext(
            progress: S0ScanProgress(scannedAssetCount: 6, totalAssetCount: 9),
            recognition: .counting,
            pendingDeletionAssetIDs: ["pending-screenshot", "not-scanned-yet"],
            ledgerAssetIDs: ["ledger-video"],
            ledgerEntries: [ledgerEntry],
            isLimitedAuthorization: true
        )
        let snapshot = S0ScanAggregator.snapshot(of: assets, context: context)

        // 类别全量：录屏同时计入大视频与屏幕录制两个类别。
        let expectedCategories = [
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 1,
                candidateByteCount: 150 * megabyte,
                recognition: .counting
            ),
            S0CategorySnapshot(
                id: .screenRecording,
                candidateCount: 1,
                candidateByteCount: 150 * megabyte,
                recognition: .counting
            ),
            S0CategorySnapshot(
                id: .screenshot,
                candidateCount: 1,
                candidateByteCount: 3 * megabyte,
                recognition: .counting
            )
        ]
        XCTAssertEqual(snapshot.categories, expectedCategories)
        // hero 去重：录屏只计一次。
        XCTAssertEqual(snapshot.cleanableAssetCount, 2)
        XCTAssertEqual(snapshot.cleanableByteCount, 153 * megabyte)
        let categorySum = snapshot.categories.reduce(Int64(0)) { total, category in
            total + category.candidateByteCount
        }
        XCTAssertEqual(categorySum, 303 * megabyte)
        XCTAssertGreaterThan(categorySum, snapshot.cleanableByteCount)

        // LIB 含不属任何类别的照片、含待删篮与账本内的资产；未解析的不进。
        XCTAssertEqual(snapshot.libraryTotalByteCount, 359 * megabyte)
        // 待删篮体积：只算已扫到且已解析的那一条。
        XCTAssertEqual(snapshot.pendingDeletionByteCount, 2 * megabyte)

        // 其余字段照原样带进快照。
        XCTAssertEqual(snapshot.progress, context.progress)
        XCTAssertEqual(snapshot.ledgerEntries, [ledgerEntry])
        XCTAssertTrue(snapshot.isLimitedAuthorization)

        // 排除集合清空后，被排除的两条回到各自类别（正对照：排除确实生效）。
        let unfiltered = S0ScanAggregator.snapshot(
            of: assets,
            context: S0ScanAggregationContext(
                progress: context.progress,
                recognition: .settled,
                pendingDeletionAssetIDs: [],
                ledgerAssetIDs: [],
                ledgerEntries: [],
                isLimitedAuthorization: false
            )
        )
        XCTAssertEqual(unfiltered.categories.map { $0.candidateCount }, [2, 1, 2])
        XCTAssertEqual(unfiltered.cleanableAssetCount, 4)
        XCTAssertEqual(unfiltered.cleanableByteCount, 355 * megabyte)
        XCTAssertEqual(unfiltered.libraryTotalByteCount, 359 * megabyte)
        XCTAssertEqual(unfiltered.pendingDeletionByteCount, 0)
        XCTAssertEqual(
            unfiltered.categories.map { $0.recognition },
            [.settled, .settled, .settled]
        )
        XCTAssertEqual(
            unfiltered.categories.map { $0.id },
            [.bigVideo, .screenRecording, .screenshot]
        )
    }

    // MARK: - 断言 3：规则登记制，分类与聚合不写裸数（子项 A）

    func testIC153A_RulesAreRegisteredNotBare() throws {
        let classifier = try XCTUnwrap(strippedSource(Self.classifierPath))
        let literals = numericLiterals(in: classifier)
        let allowed: Set<String> = ["0", "1"]
        XCTAssertTrue(
            literals.isSubset(of: allowed),
            "分类与聚合代码出现了登记表之外的裸数："
                + literals.subtracting(allowed).sorted().joined(separator: ",")
        )
        // 正对照：分类器确实经登记表取值。
        XCTAssertGreaterThanOrEqual(occurrences(of: "S0ScanRules.", in: classifier), 3)

        // 登记表：恰七个常量，每个定义处都注明出处。
        let rules = try XCTUnwrap(sourceText(Self.rulesPath))
        let lines = rules.components(separatedBy: Self.newline)
        var constantCount = 0
        for (index, line) in lines.enumerated() where line.contains("static let ") {
            constantCount += 1
            var cursor = index - 1
            var hasProvenance = false
            while cursor >= 0,
                  lines[cursor].trimmingCharacters(in: .whitespaces).hasPrefix("///") {
                if lines[cursor].contains("出处：") {
                    hasProvenance = true
                }
                cursor -= 1
            }
            XCTAssertTrue(hasProvenance, "登记常量缺出处注释：" + line)
        }
        XCTAssertEqual(constantCount, 7)
        XCTAssertEqual(occurrences(of: "出处：", in: rules), 7)

        // 正对照：同一个数字扫描器在登记表上确实看得见数。
        let rulesStripped = try XCTUnwrap(strippedSource(Self.rulesPath))
        let expectedRuleNumbers: Set<String> = ["100000000", "1206", "2622", "200"]
        XCTAssertTrue(numericLiterals(in: rulesStripped).isSuperset(of: expectedRuleNumbers))

        // 七个取值逐个钉住（任务卡白名单）。
        XCTAssertEqual(S0ScanRules.bigVideoMinimumByteCount, 100_000_000)
        XCTAssertEqual(S0ScanRules.screenRecordingFilenamePrefix, "ScreenRecording_")
        XCTAssertEqual(
            S0ScanRules.screenRecordingPixelSize,
            S0ScanPixelSize(width: 1_206, height: 2_622)
        )
        XCTAssertEqual(S0ScanRules.cacheSchemaVersion, 1)
        XCTAssertEqual(S0ScanRules.persistEveryAssets, 200)
        XCTAssertEqual(S0ScanRules.byteFetchConcurrency, 4)
        XCTAssertEqual(S0ScanRules.snapshotThrottleHz, 4)
    }

    // MARK: - 夹具

    private func assertClassification(
        _ asset: S0ScannedAsset,
        hits expectedHits: Set<S0CategoryIdentifier>,
        primary expectedPrimary: S0CategoryIdentifier?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hits = S0ScanClassifier.hits(for: asset)
        XCTAssertEqual(
            hits,
            expectedHits,
            asset.id + " 的命中集合不符",
            file: file,
            line: line
        )
        XCTAssertEqual(
            S0ScanClassifier.primaryCategory(for: hits),
            expectedPrimary,
            asset.id + " 的去重归属不符",
            file: file,
            line: line
        )
        XCTAssertEqual(
            S0ScanClassifier.classified(asset).hits,
            expectedHits,
            asset.id + " 的分类结果与命中集合不一致",
            file: file,
            line: line
        )
    }

    private func scannedAsset(
        _ id: String,
        mediaType: S0ScannedMediaType,
        isScreenshot: Bool = false,
        pixelWidth: Int = 4_032,
        pixelHeight: Int = 3_024,
        videoFilename: String? = nil,
        byteCount: Int64,
        isUnresolved: Bool = false
    ) -> S0ScannedAsset {
        S0ScannedAsset(
            id: id,
            modificationDate: Self.fixtureDate,
            creationDate: Self.fixtureDate,
            mediaType: mediaType,
            isScreenshot: isScreenshot,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            duration: mediaType == .video ? 12 : 0,
            videoFilename: videoFilename,
            byteCount: byteCount,
            isUnresolved: isUnresolved
        )
    }

    private static let fixtureDate = Date(timeIntervalSinceReferenceDate: 780_000_000.25)
    private static let rulesPath = "PhotoCleanupMVE/Services/S0ScanRules.swift"
    private static let classifierPath = "PhotoCleanupMVE/Services/S0ScanClassifier.swift"
    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148 一致）

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

    /// 取出源码里所有**独立的**数值字面量（与 IC-148 断言 3 同口径）。
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
                // 跳过整个标识符——判据必须含数字，否则指针不前进、循环不终止。
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
