import Foundation
import UIKit
import Vision
import XCTest
@testable import PhotoCleanupMVE

/// IC-175：相似照片识别引擎（批次 6 第一张；Decision_log 第 200 条第五节第 2 条单链接 0.5、第 189 条第三节参数）。
///
/// 全部断言夹具驱动：分组与相邻对是纯函数移植（探针 `SimilarPhotosProbe.swift:351-492` 同语义）；特征印象走
/// 向量路径（欧氏距离），产品的 Vision 观测路径只钉源码落位——真机的距离分布与耗时由 H92 装包判。
final class IC175SimilarRecognizerTests: XCTestCase {
    private static let recognizerPath = "PhotoCleanupMVE/Services/S0SimilarPhotosRecognizer.swift"
    private static let servicePath = "PhotoCleanupMVE/Services/S0LibraryScanService.swift"
    private static let rulesPath = "PhotoCleanupMVE/Services/S0ScanRules.swift"
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"

    // MARK: - 断言 1：规则登记

    func testIC175A_RulesAreRegisteredAndScanRulesUntouched() throws {
        XCTAssertEqual(S0SimilarPhotosRules.neighborWindowCount, 12)
        XCTAssertEqual(S0SimilarPhotosRules.neighborWindowSeconds, 600)
        XCTAssertEqual(S0SimilarPhotosRules.distanceThreshold, 0.5)
        XCTAssertEqual(S0SimilarPhotosRules.featureConcurrency, 4)
        XCTAssertEqual(S0SimilarPhotosRules.featureTargetSide, 360)
        XCTAssertEqual(S0SimilarPhotosRules.featureCacheSchemaVersion, 1)
        XCTAssertEqual(S0SimilarPhotosRules.featureCacheFileName, "s0-similar-features.plist")

        let recognizerRaw = try XCTUnwrap(sourceText(Self.recognizerPath))
        let recognizer = try XCTUnwrap(strippedSource(Self.recognizerPath))
        let rulesSlice = try XCTUnwrap(slice(recognizer, from: "enum S0SimilarPhotosRules {", to: "\n}\n"))
        XCTAssertEqual(occurrences(of: "static let ", in: rulesSlice), 7, "相似规则表恰七个常量")
        let rulesRawSlice = try XCTUnwrap(slice(recognizerRaw, from: "enum S0SimilarPhotosRules {", to: "\n}\n"))
        XCTAssertEqual(occurrences(of: "出处：", in: rulesRawSlice), 7, "每个常量都注明出处")
        let scanRules = try XCTUnwrap(strippedSource(Self.rulesPath))
        XCTAssertEqual(occurrences(of: "static let ", in: scanRules), 6, "`S0ScanRules` 仍恰六个（IC153 断言 3 的表不动）")
    }

    // MARK: - 断言 2：相邻对与分组（探针语义）

    func testIC175B_NeighborPairsAndGroupsFollowProbeSemantics() {
        let times: [Double] = [0, 100, 200, 1_000, 1_500, 1_601]
        let pairs = S0SimilarPhotosGrouping.neighborIndexPairs(times: times, maximumNeighbors: 2, windowSeconds: 600)
        XCTAssertEqual(pairs.map { [$0.0, $0.1] }, [[0, 1], [0, 2], [1, 2], [3, 4], [4, 5]])
        let single = S0SimilarPhotosGrouping.neighborIndexPairs(times: times, maximumNeighbors: 1, windowSeconds: 600)
        XCTAssertEqual(single.map { [$0.0, $0.1] }, [[0, 1], [1, 2], [3, 4], [4, 5]])
        XCTAssertEqual(S0SimilarPhotosGrouping.neighborIndexPairs(times: times, maximumNeighbors: 0, windowSeconds: 600).count, 0)

        let groups = S0SimilarPhotosGrouping.groups(
            itemCount: 6,
            pairs: [(0, 1, 0.5), (1, 2, 0.51), (3, 4, 0.2), (4, 5, 0.49), (9, 10, 0.1)],
            threshold: 0.5
        )
        XCTAssertEqual(groups, [[0, 1], [3, 4, 5]], "等于阈值连边、越界对忽略、单链接")
        let summary = S0SimilarPhotosGrouping.summary(groups: groups)
        XCTAssertEqual(summary, S0SimilarPhotosGrouping.Summary(groupCount: 2, groupedCount: 5, largestGroupSize: 3, removableCount: 3))
        XCTAssertEqual(S0SimilarPhotosGrouping.groups(itemCount: 0, pairs: [(0, 1, 0)], threshold: 1).count, 0)
    }

    // MARK: - 断言 3：向量印象的归档往返与距离

    func testIC175C_VectorPrintArchiveRoundTripAndDistances() throws {
        let first = S0FeaturePrint(vector: [0, 0, 3], revision: 2)
        let second = S0FeaturePrint(vector: [0, 4, 0], revision: 2)
        XCTAssertEqual(try XCTUnwrap(first.distance(to: second)), 5, accuracy: 0.000_001)
        XCTAssertFalse(first.isObservation)

        let archive = try XCTUnwrap(first.archived())
        XCTAssertEqual(archive.count, 1 + 4 + 4 + 3 * 4)
        let restored = try XCTUnwrap(S0FeaturePrint.unarchived(archive))
        XCTAssertEqual(restored.revision, 2)
        XCTAssertEqual(try XCTUnwrap(restored.distance(to: second)), 5, accuracy: 0.000_001)

        XCTAssertNil(S0FeaturePrint.unarchived(Data()))
        XCTAssertNil(S0FeaturePrint.unarchived(Data([9, 1, 2, 3])))
        XCTAssertNil(S0FeaturePrint.unarchived(archive.dropLast()), "长度对不上即拒")
        XCTAssertNil(first.distance(to: S0FeaturePrint(vector: [1, 2], revision: 2)), "维数不同无距离")
    }

    // MARK: - 断言 4：特征缓存文件

    func testIC175C_FeatureCacheStoreRoundTripAndSchemaMismatch() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ic175-" + UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent(S0SimilarPhotosRules.featureCacheFileName)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = S0SimilarFeatureCacheStore(fileURL: fileURL)
        XCTAssertEqual(store.load(), [:], "无文件即空")

        let date = Date(timeIntervalSince1970: 1_700_000_000.25)
        let archive = try XCTUnwrap(S0FeaturePrint(vector: [1, 2, 3], revision: 2).archived())
        let entries = [
            "a": S0SimilarFeatureCacheEntry(modificationDate: date, revision: 2, archive: archive),
            "b": S0SimilarFeatureCacheEntry(modificationDate: nil, revision: 2, archive: archive)
        ]
        try store.save(entries)
        XCTAssertEqual(store.load(), entries, "小数秒与 nil 日期都往返")

        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let stale = try encoder.encode(
            S0SimilarFeatureCacheFile(schemaVersion: S0SimilarPhotosRules.featureCacheSchemaVersion + 1, entries: entries)
        )
        try stale.write(to: fileURL, options: .atomic)
        XCTAssertEqual(store.load(), [:], "版本不符整份作废")
        try Data([0, 1, 2]).write(to: fileURL, options: .atomic)
        XCTAssertEqual(store.load(), [:], "解不开当空缓存")
    }

    // MARK: - 断言 5：识别器复用缓存、按修改时间与 revision 作废、分组确定

    func testIC175D_RecognizerReusesCacheAndRegroups() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ic175-" + UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let store = S0SimilarFeatureCacheStore(
            fileURL: directory.appendingPathComponent(S0SimilarPhotosRules.featureCacheFileName)
        )
        let recognizer = S0SimilarPhotosRecognizer(cacheStore: store)
        let d1 = Date(timeIntervalSince1970: 1_000)
        let d2 = Date(timeIntervalSince1970: 2_000)
        var candidates = [
            S0SimilarCandidate(id: "c", modificationDate: d1, creationTime: 20),
            S0SimilarCandidate(id: "a", modificationDate: d1, creationTime: 0),
            S0SimilarCandidate(id: "d", modificationDate: d1, creationTime: 10_000),
            S0SimilarCandidate(id: "b", modificationDate: d1, creationTime: 10)
        ]
        let vectors: [String: [Float]] = ["a": [0, 0], "b": [0.3, 0], "c": [0.9, 0], "d": [5, 5]]
        let counter = CallCounter()
        let extract: (String) -> S0FeaturePrintOutcome = { identifier in
            counter.record(identifier)
            guard let vector = vectors[identifier] else {
                return .failed
            }
            return .extracted(S0FeaturePrint(vector: vector, revision: 7))
        }

        let first = run(recognizer, candidates: candidates, revision: 7, extract: extract)
        XCTAssertEqual(first.candidateCount, 4)
        XCTAssertEqual(first.extractedCount, 4)
        XCTAssertEqual(first.reusedCount, 0)
        XCTAssertEqual(first.pairCount, 3, "a-b、a-c、b-c 在窗内，d 在窗外")
        XCTAssertEqual(first.distanceFailedCount, 0)
        XCTAssertEqual(first.groups, [["a", "b"]], "0.3 连、0.6 与 0.9 不连")
        XCTAssertEqual(first.revision, 7)
        XCTAssertFalse(first.cancelled)
        XCTAssertFalse(first.cacheWriteFailed)
        XCTAssertEqual(counter.sorted, ["a", "b", "c", "d"])
        XCTAssertEqual(store.load().count, 4)

        counter.reset()
        let second = run(recognizer, candidates: candidates, revision: 7, extract: extract)
        XCTAssertEqual(second.reusedCount, 4)
        XCTAssertEqual(second.extractedCount, 0)
        XCTAssertEqual(second.groups, [["a", "b"]])
        XCTAssertEqual(counter.sorted, [], "全部复用，一次都不提取")

        counter.reset()
        candidates[3] = S0SimilarCandidate(id: "b", modificationDate: d2, creationTime: 10)
        let third = run(recognizer, candidates: candidates, revision: 7, extract: extract)
        XCTAssertEqual(third.reusedCount, 3)
        XCTAssertEqual(third.extractedCount, 1)
        XCTAssertEqual(counter.sorted, ["b"], "只重取修改时间变了的那张")

        counter.reset()
        let fourth = run(recognizer, candidates: candidates, revision: 8, extract: extract)
        XCTAssertEqual(fourth.reusedCount, 0)
        XCTAssertEqual(fourth.extractedCount, 4)
        XCTAssertEqual(counter.sorted, ["a", "b", "c", "d"], "revision 变了整份作废")

        counter.reset()
        let dropped = run(recognizer, candidates: Array(candidates.prefix(2)), revision: 8, extract: extract)
        XCTAssertEqual(dropped.candidateCount, 2)
        XCTAssertEqual(store.load().count, 2, "库内已无的条目随重写丢弃")

        let token = S0SimilarCancellationToken()
        token.cancel()
        counter.reset()
        let cancelled = run(
            S0SimilarPhotosRecognizer(cacheStore: nil),
            candidates: candidates,
            revision: 9,
            extract: extract,
            cancellation: token
        )
        XCTAssertTrue(cancelled.cancelled)
        XCTAssertEqual(cancelled.extractedCount, 0)
        XCTAssertEqual(cancelled.groups.count, 0)
        XCTAssertEqual(counter.sorted, [], "取消后不发起提取")
    }

    // MARK: - 断言 6：扫描服务一遍末尾跑识别、诊断文本、快照不变

    func testIC175E_ScanServiceRunsRecognitionAfterPassAndReportsDiagnostics() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ic175-" + UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        // 库：四张普通照片（a、b、c 相隔 60 s，d 隔一天）、一张截图、一张视频、一张未解析照片。
        // 候选只应是 a、b、c、d：截图、视频、未解析都不进识别。
        let library: [S0AssetMetadata] = [
            metadata("a", creationOffset: 0, mediaType: .photo, isScreenshot: false),
            metadata("b", creationOffset: 60, mediaType: .photo, isScreenshot: false),
            metadata("c", creationOffset: 120, mediaType: .photo, isScreenshot: false),
            metadata("shot", creationOffset: 130, mediaType: .photo, isScreenshot: true),
            metadata("clip", creationOffset: 140, mediaType: .video, isScreenshot: false),
            metadata("cloud", creationOffset: 150, mediaType: .photo, isScreenshot: false),
            metadata("d", creationOffset: 86_400, mediaType: .photo, isScreenshot: false)
        ]
        let vectors: [String: [Float]] = ["a": [0, 0], "b": [0.2, 0], "c": [0.9, 0], "d": [4, 4]]
        let counter = CallCounter()
        let source = S0LibraryScanSource(
            authorizationState: { .authorized },
            enumerateAssets: { library },
            fetchResourcesAndBytes: { identifier in
                (videoFilename: nil, byteCount: identifier == "cloud" ? nil : 1_000)
            },
            extractFeaturePrint: { identifier in
                counter.record(identifier)
                guard let vector = vectors[identifier] else {
                    return .failed
                }
                return .extracted(S0FeaturePrint(vector: vector, revision: 3))
            }
        )
        let service = S0LibraryScanService(
            source: source,
            cacheStore: S0ScanCacheStore(directoryURL: directory),
            similarRecognizer: S0SimilarPhotosRecognizer(
                cacheStore: S0SimilarFeatureCacheStore(
                    fileURL: directory.appendingPathComponent(S0SimilarPhotosRules.featureCacheFileName)
                )
            )
        )
        XCTAssertTrue(service.similarDiagnosticsReport().hasPrefix("format=ic175-similar-v1"))
        XCTAssertTrue(service.similarDiagnosticsReport().contains("state=idle"))

        service.advanceScan()
        XCTAssertTrue(waitUntil(timeout: 20) { !service.isScanInFlight })
        XCTAssertEqual(service.currentScanOutcome(), .completed)

        let result = service.similarRecognitionResult
        XCTAssertEqual(result.candidateCount, 4, "截图、视频、未解析不进候选")
        XCTAssertEqual(counter.sorted, ["a", "b", "c", "d"])
        XCTAssertEqual(result.extractedCount, 4)
        XCTAssertEqual(result.pairCount, 3, "a-b、a-c、b-c；d 在窗外")
        XCTAssertEqual(result.groups, [["a", "b"]])
        XCTAssertFalse(result.cancelled)
        XCTAssertFalse(result.cacheWriteFailed)

        let report = service.similarDiagnosticsReport()
        XCTAssertTrue(report.contains("state=done"), report)
        XCTAssertTrue(report.contains("candidates=4 reused=0 extracted=4 in_cloud=0 failed=0"), report)
        XCTAssertTrue(report.contains("groups=1 grouped=2 largest=2 removable=1"), report)
        XCTAssertTrue(report.contains("threshold=0.50 window=12/600"), report)
        XCTAssertTrue(report.contains("cache_write=ok cancelled=0"), report)
        XCTAssertTrue(report.unicodeScalars.allSatisfy { $0.isASCII }, "全 ASCII")

        // 快照不因识别而变：`similar` 仍不在 `CAT`，四条不多不少。
        let snapshot = service.currentSnapshot()
        XCTAssertEqual(snapshot.categories.map(\.id), [.bigVideo, .screenRecording, .screenshot, .rest])
        XCTAssertFalse(snapshot.categories.contains { $0.id == .similar })
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(S0SimilarPhotosRules.featureCacheFileName).path
        ), "特征缓存落在给定目录")

        // 第二遍：全部复用，不再提取。
        counter.reset()
        service.advanceScan()
        XCTAssertTrue(waitUntil(timeout: 20) { !service.isScanInFlight })
        XCTAssertEqual(service.similarRecognitionResult.reusedCount, 4)
        XCTAssertEqual(service.similarRecognitionResult.extractedCount, 0)
        XCTAssertEqual(counter.sorted, [])
        XCTAssertEqual(service.similarRecognitionResult.groups, [["a", "b"]])
    }

    // MARK: - 断言 6b：产品路径的观测归档往返（宿主上 Vision 不可用即跳过，不判红）

    func testIC175C_ObservationArchiveRoundTripKeepsDistanceZero() throws {
        guard let image = makeTestImage() else {
            throw XCTSkip("no CGImage")
        }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw XCTSkip("Vision unavailable on this host: " + String(describing: error))
        }
        guard let observation = (request.results ?? []).first as? VNFeaturePrintObservation else {
            throw XCTSkip("Vision returned no feature print on this host")
        }
        let original = S0FeaturePrint(observation: observation)
        XCTAssertTrue(original.isObservation)
        XCTAssertEqual(original.revision, request.revision)
        let archive = try XCTUnwrap(original.archived())
        XCTAssertEqual(archive.first, 1, "观测归档首字节为 1")
        let restored = try XCTUnwrap(S0FeaturePrint.unarchived(archive))
        XCTAssertTrue(restored.isObservation)
        XCTAssertEqual(try XCTUnwrap(restored.distance(to: original)), 0, accuracy: 0.000_01)
        XCTAssertNil(restored.distance(to: S0FeaturePrint(vector: [0], revision: 1)), "观测与向量之间无距离")
    }

    private func makeTestImage() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        let image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 8, y: 8, width: 30, height: 40))
        }
        return image.cgImage
    }

    private func metadata(
        _ identifier: String,
        creationOffset: TimeInterval,
        mediaType: S0ScannedMediaType,
        isScreenshot: Bool
    ) -> S0AssetMetadata {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return S0AssetMetadata(
            localIdentifier: identifier,
            modificationDate: base,
            creationDate: base.addingTimeInterval(creationOffset),
            mediaType: mediaType,
            isScreenshot: isScreenshot,
            pixelWidth: 100,
            pixelHeight: 100,
            duration: 0
        )
    }

    /// 主线程轮询（照 IC153 的写法）：服务回调经主队列送达。
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return condition()
    }

    // MARK: - 断言 7：源码落位

    func testIC175F_SourceDisciplineAndWiring() throws {
        let recognizerRaw = try XCTUnwrap(sourceText(Self.recognizerPath))
        let recognizer = try XCTUnwrap(strippedSource(Self.recognizerPath))
        XCTAssertEqual(occurrences(of: "import Vision", in: recognizerRaw), 1)
        XCTAssertEqual(occurrences(of: "isNetworkAccessAllowed = false", in: recognizer), 1)
        XCTAssertEqual(occurrences(of: "isSynchronous = true", in: recognizer), 1)
        XCTAssertEqual(occurrences(of: "fetchAssets", in: recognizer), 0, "不按标识再查库，复用一遍枚举留存的对象")
        XCTAssertEqual(occurrences(of: "withLocalIdentifiers", in: recognizer), 0)
        XCTAssertEqual(occurrences(of: "Task.detached", in: recognizer), 0)
        XCTAssertEqual(occurrences(of: "withTaskGroup", in: recognizer), 0)
        XCTAssertEqual(occurrences(of: "DispatchSemaphore(", in: recognizer), 1)
        XCTAssertEqual(occurrences(of: "computeDistance(", in: recognizer), 1)
        XCTAssertEqual(occurrences(of: "NSKeyedArchiver.archivedData(", in: recognizer), 1)
        XCTAssertEqual(occurrences(of: "NSKeyedUnarchiver.unarchivedObject(", in: recognizer), 1)
        XCTAssertEqual(occurrences(of: "return \"", in: recognizerRaw), 0)

        let service = try XCTUnwrap(strippedSource(Self.servicePath))
        XCTAssertEqual(occurrences(of: "withCheckedContinuation", in: service), 1)
        XCTAssertEqual(occurrences(of: "withTaskCancellationHandler", in: service), 1)
        XCTAssertEqual(occurrences(of: "extractFeaturePrint", in: service), 4, "源字段、生产闭包标签与调用、一遍末尾取用")
        XCTAssertEqual(occurrences(of: "func cachedAsset(for identifier: String) -> PHAsset?", in: service), 1)
        XCTAssertEqual(occurrences(of: "private func cachedAsset", in: service), 0)
        XCTAssertEqual(occurrences(of: "func similarDiagnosticsReport() -> String", in: service), 1)
        XCTAssertEqual(occurrences(of: "import Vision", in: try XCTUnwrap(sourceText(Self.servicePath))), 0)

        let s2View = try XCTUnwrap(strippedSource(Self.s2ViewPath))
        let s2ViewRaw = try XCTUnwrap(sourceText(Self.s2ViewPath))
        XCTAssertEqual(occurrences(of: "similarDiagnosticsSection", in: s2View), 2, "声明一处、挂载一处")
        XCTAssertEqual(occurrences(of: "similarDiagnosticsText: String? = nil", in: s2View), 1)
        XCTAssertEqual(occurrences(of: "s2.calibration.similar_diagnostics.", in: s2ViewRaw), 3)

        let app = try XCTUnwrap(sourceText(Self.appPath))
        XCTAssertEqual(occurrences(of: "similarDiagnosticsText: s0DataProvider.similarDiagnosticsReport()", in: app), 1)

        let catalog = try XCTUnwrap(sourceText(Self.catalogPath))
        for key in ["title", "share", "empty"] {
            XCTAssertEqual(occurrences(of: "\"s2.calibration.similar_diagnostics." + key + "\"", in: catalog), 1, key)
        }
    }

    // MARK: - 夹具

    private final class CallCounter {
        private let lock = NSLock()
        private var identifiers: [String] = []

        func record(_ identifier: String) {
            lock.lock()
            identifiers.append(identifier)
            lock.unlock()
        }

        func reset() {
            lock.lock()
            identifiers = []
            lock.unlock()
        }

        /// 并发填充只做顺序无关比较（陷阱 10）。
        var sorted: [String] {
            lock.lock()
            defer {
                lock.unlock()
            }
            return identifiers.sorted()
        }
    }

    private func run(
        _ recognizer: S0SimilarPhotosRecognizer,
        candidates: [S0SimilarCandidate],
        revision: Int,
        extract: @escaping (String) -> S0FeaturePrintOutcome,
        cancellation: S0SimilarCancellationToken = S0SimilarCancellationToken()
    ) -> S0SimilarRecognitionResult {
        let done = expectation(description: "recognized")
        let box = ResultBox()
        recognizer.recognize(
            candidates: candidates,
            revision: revision,
            extract: extract,
            cancellation: cancellation
        ) { result in
            box.result = result
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        return box.result ?? .idle
    }

    private final class ResultBox {
        var result: S0SimilarRecognitionResult?
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

    private func slice(_ source: String, from start: String, to end: String) -> String? {
        guard let startRange = source.range(of: start) else {
            return nil
        }
        guard let endRange = source.range(of: end, range: startRange.upperBound..<source.endIndex) else {
            return nil
        }
        return String(source[startRange.lowerBound..<endRange.upperBound])
    }
}
