import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-155：批次 5.2a 类别数据接口与封面——`coverAssetID` 进模型、按类别取有序资产
/// 列表、首页类别行接真封面。
///
/// 依据 SPEC-S0 v2（SHA-256 `8A8E…6F44`）第三节第 2 部分（类别行单张封面取该类别
/// 按当前排序的第一项）、第六节（三列网格按 `SZ(a)` 降序）、第十四节封面几何，与
/// 任务卡 IC-20260916-155 的五条裁定。断言编号与任务卡一一对应：1～3 属子项 A，
/// 4～7 属子项 B，8～9 属子项 C；本文件随三个子项的提交逐段追加。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：封面是不是真机上最大的那一张、iCloud 优化
/// 储存时的空槽、滚动与切 tab 时封面不闪不串，只有 H76 能判。
final class IC155CategoryDataAndCoverTests: XCTestCase {

    // MARK: - 断言 1：封面 = 候选集中体积最大者，同体积取标识升序（子项 A）

    func testIC155A_CoverIsLargestCandidateWithDeterministicTie() {
        let megabyte: Int64 = 1_000_000
        // IC-153 断言 2 同型夹具，外加两条同体积、且大于既有截图的截图。
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
        // 账本内的视频比录屏大：它若没被排除，大视频的封面就会是它。
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
        // 先 b 后 a：并列时若按到达顺序取，封面会是 b。
        let shotB = scannedAsset(
            "shot-b",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 5 * megabyte
        )
        let shotA = scannedAsset(
            "shot-a",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 5 * megabyte
        )
        let fixture = [
            recording,
            screenshot,
            plainPhoto,
            pendingScreenshot,
            ledgerVideo,
            unresolvedVideo,
            shotB,
            shotA
        ]
        let assets = fixture.map { S0ScanClassifier.classified($0) }
        let pending: Set<String> = ["pending-screenshot", "not-scanned-yet"]

        let snapshot = S0ScanAggregator.snapshot(
            of: assets,
            context: aggregationContext(pending: pending, ledger: ["ledger-video"])
        )
        XCTAssertEqual(
            snapshot.categories.map { $0.id },
            [.bigVideo, .screenRecording, .screenshot]
        )
        XCTAssertEqual(category(.bigVideo, in: snapshot)?.coverAssetID, "recording")
        XCTAssertEqual(category(.screenRecording, in: snapshot)?.coverAssetID, "recording")
        XCTAssertEqual(category(.screenshot, in: snapshot)?.coverAssetID, "shot-a")
        // 候选集与 `candidateCount` 同源：截图三条（3 MB + 5 MB × 2）。
        XCTAssertEqual(category(.screenshot, in: snapshot)?.candidateCount, 3)
        XCTAssertEqual(
            category(.screenshot, in: snapshot)?.candidateByteCount,
            13 * megabyte
        )

        // 并列的首选进了待删篮：封面换成并列的另一条（排除规则与计数同源）。
        let withShotAPending = S0ScanAggregator.snapshot(
            of: assets,
            context: aggregationContext(
                pending: pending.union(["shot-a"]),
                ledger: ["ledger-video"]
            )
        )
        XCTAssertEqual(category(.screenshot, in: withShotAPending)?.coverAssetID, "shot-b")
        XCTAssertEqual(category(.screenshot, in: withShotAPending)?.candidateCount, 2)
        XCTAssertEqual(
            category(.bigVideo, in: withShotAPending)?.coverAssetID,
            "recording"
        )

        // 正对照：账本清空后，更大的账本视频回到大视频类别并成为封面。
        let withoutLedger = S0ScanAggregator.snapshot(
            of: assets,
            context: aggregationContext(pending: pending, ledger: [])
        )
        XCTAssertEqual(category(.bigVideo, in: withoutLedger)?.coverAssetID, "ledger-video")
        XCTAssertEqual(
            category(.screenRecording, in: withoutLedger)?.coverAssetID,
            "recording"
        )

        // 全部候选都未解析：三个类别都无项目，封面一律 nil。
        let allUnresolved = [recording, screenshot, shotB, shotA].map { asset in
            S0ScanClassifier.classified(
                S0ScannedAsset(
                    id: asset.id,
                    modificationDate: asset.modificationDate,
                    creationDate: asset.creationDate,
                    mediaType: asset.mediaType,
                    isScreenshot: asset.isScreenshot,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.duration,
                    videoFilename: asset.videoFilename,
                    byteCount: 0,
                    isUnresolved: true
                )
            )
        }
        let empty = S0ScanAggregator.snapshot(
            of: allUnresolved,
            context: aggregationContext(pending: [], ledger: [])
        )
        XCTAssertEqual(empty.categories.count, 3)
        for emptyCategory in empty.categories {
            XCTAssertEqual(emptyCategory.candidateCount, 0)
            XCTAssertNil(emptyCategory.coverAssetID)
        }
    }

    // MARK: - 断言 2：封面与输入顺序无关（子项 A，陷阱 10）

    func testIC155A_CoverIsOrderIndependent() {
        let megabyte: Int64 = 1_000_000
        // 每个类别都安排并列，且标识最小的那一条都不在原序首位。
        let fixture = [
            scannedAsset(
                "big-c",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0101.MOV",
                byteCount: 300 * megabyte
            ),
            scannedAsset(
                "rec-z",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "ScreenRecording_01-01-2026 10-00-00_1.mp4",
                byteCount: 40 * megabyte
            ),
            scannedAsset(
                "shot-b",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 5 * megabyte
            ),
            scannedAsset(
                "big-a",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0102.MOV",
                byteCount: 300 * megabyte
            ),
            scannedAsset("plain-photo", mediaType: .photo, byteCount: 4 * megabyte),
            scannedAsset(
                "rec-y",
                mediaType: .video,
                pixelWidth: 2_622,
                pixelHeight: 1_206,
                videoFilename: "IMG_0103.MP4",
                byteCount: 40 * megabyte
            ),
            scannedAsset(
                "big-b",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0104.MOV",
                byteCount: 300 * megabyte
            ),
            scannedAsset(
                "shot-a",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 5 * megabyte
            ),
            scannedAsset(
                "small-shot",
                mediaType: .photo,
                isScreenshot: true,
                byteCount: 1 * megabyte
            )
        ]
        let assets = fixture.map { S0ScanClassifier.classified($0) }
        let evens = assets.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        let odds = assets.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
        let orders: [[S0ClassifiedAsset]] = [
            assets,
            Array(assets.reversed()),
            Array(assets.dropFirst(2)) + Array(assets.prefix(2)),
            Array(assets.dropFirst(5)) + Array(assets.prefix(5)),
            evens + odds
        ]
        // 前置：五种顺序确实两两不同，否则「逐次相同」会空转通过。
        XCTAssertEqual(Set(orders.map { order in order.map { $0.id } }).count, 5)

        let context = aggregationContext(pending: [], ledger: [])
        let reference = S0ScanAggregator.snapshot(of: orders[0], context: context)
        XCTAssertEqual(
            reference.categories.map { $0.coverAssetID },
            ["big-a", "rec-y", "shot-a"]
        )
        for order in orders {
            let snapshot = S0ScanAggregator.snapshot(of: order, context: context)
            XCTAssertEqual(
                snapshot.categories.map { $0.coverAssetID },
                reference.categories.map { $0.coverAssetID }
            )
            XCTAssertEqual(snapshot, reference)
        }
    }

    // MARK: - 断言 3：带默认值的字段不打红既有构造（子项 A）

    func testIC155A_DefaultedFieldKeepsExistingConstructionsUntouched() throws {
        let model = try XCTUnwrap(strippedSource(Self.stateMachinePath))
        XCTAssertEqual(occurrences(of: "let coverAssetID: String?", in: model), 1)
        XCTAssertEqual(occurrences(of: "coverAssetID: String? = nil", in: model), 1)

        // IC-147／IC-148 的构造点一个标签都没加。IC-148 断言 14 的新 needle 是字符串
        // 字面量，剔过的源码里不留，故扫剔过的源码。
        let behavior = try XCTUnwrap(strippedSource(Self.behaviorTestsPath))
        let visual = try XCTUnwrap(strippedSource(Self.visualTestsPath))
        XCTAssertEqual(occurrences(of: "coverAssetID:", in: behavior), 0)
        XCTAssertEqual(occurrences(of: "coverAssetID:", in: visual), 0)
        // 正对照：两文件的构造点确实还在（15 + 3），扫描不是空转。
        XCTAssertEqual(occurrences(of: "S0CategorySnapshot(", in: behavior), 15)
        XCTAssertEqual(occurrences(of: "S0CategorySnapshot(", in: visual), 3)

        // 不带标签构造即为 nil（默认值生效）。
        let legacy = S0CategorySnapshot(
            id: .bigVideo,
            candidateCount: 12,
            candidateByteCount: 4_800_000_000,
            recognition: .settled
        )
        XCTAssertNil(legacy.coverAssetID)
        XCTAssertNotEqual(
            legacy,
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 12,
                candidateByteCount: 4_800_000_000,
                recognition: .settled,
                coverAssetID: "cover"
            )
        )

        // 桩：有项目的行封面为合成标识，无项目的行为 nil（A3 在子项 A 内定死）。
        let ready = S0CleanupDataStub(scenario: .readyWithItems).currentSnapshot()
        for readyCategory in ready.categories {
            XCTAssertEqual(
                readyCategory.coverAssetID,
                "stub." + readyCategory.id.rawValue + ".1"
            )
        }
        let readyEmpty = S0CleanupDataStub(scenario: .readyWithoutItems).currentSnapshot()
        XCTAssertEqual(readyEmpty.categories.count, 5)
        XCTAssertTrue(readyEmpty.categories.allSatisfy { $0.coverAssetID == nil })
        let scanningStart = S0CleanupDataStub(scenario: .scanning).currentSnapshot()
        XCTAssertTrue(scanningStart.categories.allSatisfy { $0.coverAssetID == nil })
    }

    // MARK: - 夹具

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

    private func aggregationContext(
        pending: Set<String>,
        ledger: Set<String>
    ) -> S0ScanAggregationContext {
        S0ScanAggregationContext(
            progress: S0ScanProgress(scannedAssetCount: 8, totalAssetCount: 8),
            recognition: .settled,
            pendingDeletionAssetIDs: pending,
            ledgerAssetIDs: ledger,
            ledgerEntries: [],
            isLimitedAuthorization: false
        )
    }

    private func category(
        _ identifier: S0CategoryIdentifier,
        in snapshot: S0CleanupSnapshot
    ) -> S0CategorySnapshot? {
        snapshot.categories.first { $0.id == identifier }
    }

    private static let fixtureDate = Date(timeIntervalSinceReferenceDate: 780_000_000.25)
    private static let stateMachinePath = "PhotoCleanupMVE/Core/S0StateMachine.swift"
    private static let behaviorTestsPath = "PhotoCleanupMVETests/IC147S0BehaviorTests.swift"
    private static let visualTestsPath = "PhotoCleanupMVETests/IC148S0VisualTests.swift"

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148／IC-153 一致）

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
}
