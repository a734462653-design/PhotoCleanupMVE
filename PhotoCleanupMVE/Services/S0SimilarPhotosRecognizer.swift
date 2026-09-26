import Foundation
import Photos
import UIKit
import Vision

/// IC-175：相似照片识别的规则登记常量（批次 6 相似照片，第一张：识别引擎）。
///
/// 与 `S0ScanRules` 分表：那张表被 `IC153ScanServiceTests` 断言 3 钉住恰六个常量；本表只
/// 管相似识别。分类与聚合文件不引用本表（本卡 `similar` 不进归属）。
enum S0SimilarPhotosRules {
    /// 相邻对判定：每张只与其后至多这么多张比。
    /// 出处：SPEC-S0 v4 第七节第 2 部分（探针口径，Decision_log 第 189 条第三节）。
    static let neighborWindowCount = 12

    /// 相邻对判定：拍摄时间差上限（秒）。
    /// 出处：同上。
    static let neighborWindowSeconds: Double = 600

    /// 距离小于等于阈值连边，取连通分量（单链接，无簇内最大距离约束）。
    /// 出处：SPEC-S0 v4 `:353` 默认档 0.5；Decision_log 第 200 条第五节第 2 条（④）。
    static let distanceThreshold: Double = 0.5

    /// 特征提取并发上限。
    /// 出处：SPEC-S0 v4 `:384`；H80 实测并发 4 全库 9.3 s（Decision_log 第 189 条第三节）。
    static let featureConcurrency = 4

    /// 取图长边（点）。
    /// 出处：SPEC-S0 v4 `:384`。
    static let featureTargetSide: CGFloat = 360

    /// 特征缓存文件名，与扫描缓存同目录。键 `localIdentifier`，复用判据 `modificationDate` +
    /// 特征 revision 都相同。
    /// 出处：SPEC-S0 v4 `:384`（键与扫描缓存同源）；IC-175 裁定 三（另开文件、带 revision）。
    static let featureCacheFileName = "s0-similar-features.plist"

    /// 特征缓存结构版本，从 1 起；文件内版本与此不符即整份作废、重新提取。
    /// 出处：IC-175 裁定 三。
    static let featureCacheSchemaVersion = 1
}

/// 一张照片的特征印象。
///
/// 产品路径包 Vision 观测：距离经 `computeDistance`，与探针 `probe/ic-161-similar-photos`
/// 同一口径（Lynn 判 0.5 所依据的数就是它）；归档走 `NSKeyedArchiver`（`VNObservation` 支持
/// 安全编码），解档后仍可算距离，不必自己复现距离公式。
/// 测试路径用浮点向量（欧氏距离），归档为小端 Float32 序列。两种归档首字节不同、各自往返；
/// 观测与向量之间没有距离（返回 nil，计入距离失败）。
final class S0FeaturePrint {
    private enum Payload {
        case observation(VNFeaturePrintObservation)
        case vector([Float])
    }

    private static let observationTag: UInt8 = 1
    private static let vectorTag: UInt8 = 2

    private let payload: Payload
    /// 产出本印象的请求 revision。跨 revision 的距离不可比，缓存按它作废。
    let revision: Int

    init(observation: VNFeaturePrintObservation) {
        payload = .observation(observation)
        revision = observation.requestRevision
    }

    init(vector: [Float], revision: Int) {
        payload = .vector(vector)
        self.revision = revision
    }

    var isObservation: Bool {
        if case .observation = payload {
            return true
        }
        return false
    }

    func distance(to other: S0FeaturePrint) -> Double? {
        switch (payload, other.payload) {
        case let (.observation(lhs), .observation(rhs)):
            var value = Float(0)
            do {
                try lhs.computeDistance(&value, to: rhs)
            } catch {
                return nil
            }
            return Double(value)
        case let (.vector(lhs), .vector(rhs)):
            guard lhs.count == rhs.count else {
                return nil
            }
            var sum: Double = 0
            for index in lhs.indices {
                let difference = Double(lhs[index]) - Double(rhs[index])
                sum += difference * difference
            }
            return sum.squareRoot()
        default:
            return nil
        }
    }

    /// 归档。失败为 nil（不入缓存，下次重新提取）。
    func archived() -> Data? {
        switch payload {
        case let .observation(observation):
            guard let body = try? NSKeyedArchiver.archivedData(
                withRootObject: observation,
                requiringSecureCoding: true
            ) else {
                return nil
            }
            var data = Data([Self.observationTag])
            data.append(body)
            return data
        case let .vector(vector):
            var data = Data([Self.vectorTag])
            var revisionValue = Int32(clamping: revision).littleEndian
            var countValue = Int32(clamping: vector.count).littleEndian
            withUnsafeBytes(of: &revisionValue) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: &countValue) { data.append(contentsOf: $0) }
            for element in vector {
                var bits = element.bitPattern.littleEndian
                withUnsafeBytes(of: &bits) { data.append(contentsOf: $0) }
            }
            return data
        }
    }

    static func unarchived(_ data: Data) -> S0FeaturePrint? {
        guard let tag = data.first else {
            return nil
        }
        let body = data.dropFirst()
        if tag == observationTag {
            guard let observation = try? NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: Data(body)
            ) else {
                return nil
            }
            return S0FeaturePrint(observation: observation)
        }
        guard tag == vectorTag, body.count >= 8 else {
            return nil
        }
        let bytes = [UInt8](body)
        func int32(at offset: Int) -> Int32 {
            var value: UInt32 = 0
            for step in 0..<4 {
                value |= UInt32(bytes[offset + step]) << (8 * UInt32(step))
            }
            return Int32(bitPattern: value)
        }
        let revision = Int(int32(at: 0))
        let count = Int(int32(at: 4))
        guard count >= 0, bytes.count == 8 + count * 4 else {
            return nil
        }
        var vector: [Float] = []
        vector.reserveCapacity(count)
        for index in 0..<count {
            let offset = 8 + index * 4
            var bits: UInt32 = 0
            for step in 0..<4 {
                bits |= UInt32(bytes[offset + step]) << (8 * UInt32(step))
            }
            vector.append(Float(bitPattern: bits))
        }
        return S0FeaturePrint(vector: vector, revision: revision)
    }
}

/// 一次特征提取的结果。
enum S0FeaturePrintOutcome {
    case extracted(S0FeaturePrint)
    /// iCloud 未下载：本卡禁网络，跳过、不计失败（与未解析资产同口径）。
    case inCloud
    case failed
}

/// 相似识别的候选：库内已解析的非截图照片。三个字段都来自扫描缓存条目，识别不再碰 PhotoKit
/// 元数据；拍摄时间缺失取 0（探针口径）。
struct S0SimilarCandidate: Equatable, Sendable {
    let id: String
    let modificationDate: Date?
    let creationTime: Double
}

/// 特征缓存条目：键即 `localIdentifier`（字典键），条目不重复存。
struct S0SimilarFeatureCacheEntry: Codable, Equatable {
    let modificationDate: Date?
    let revision: Int
    let archive: Data
}

struct S0SimilarFeatureCacheFile: Codable, Equatable {
    let schemaVersion: Int
    let entries: [String: S0SimilarFeatureCacheEntry]
}

private struct S0SimilarFeatureCacheHeader: Codable {
    let schemaVersion: Int
}

/// 特征缓存文件存储（照 `S0ScanCacheStore` 的形状）：二进制属性列表、原子写、`NSLock`。
/// 读不到、版本不符或整份解不开都当空缓存；缓存是加速器不是数据源，失败只让下次重新提取。
final class S0SimilarFeatureCacheStore {
    private let fileURL: URL
    private let lock = NSLock()

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    /// 产品构造：Application Support 下与扫描缓存同一目录。
    convenience init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent(S0ScanCacheStore.directoryName, isDirectory: true)
        self.init(fileURL: directory.appendingPathComponent(S0SimilarPhotosRules.featureCacheFileName))
    }

    func load() -> [String: S0SimilarFeatureCacheEntry] {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            return [:]
        }
        let decoder = PropertyListDecoder()
        guard let header = try? decoder.decode(S0SimilarFeatureCacheHeader.self, from: data),
              header.schemaVersion == S0SimilarPhotosRules.featureCacheSchemaVersion,
              let file = try? decoder.decode(S0SimilarFeatureCacheFile.self, from: data) else {
            return [:]
        }
        return file.entries
    }

    func save(_ entries: [String: S0SimilarFeatureCacheEntry]) throws {
        lock.lock()
        defer {
            lock.unlock()
        }
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        let data = try encoder.encode(
            S0SimilarFeatureCacheFile(
                schemaVersion: S0SimilarPhotosRules.featureCacheSchemaVersion,
                entries: entries
            )
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

/// 分组纯函数，移植自探针 `SimilarPhotosProbe.swift:351-492`（`neighborIndexPairs`／`groups`／
/// `summary` 逐字，只换类型名）。
enum S0SimilarPhotosGrouping {
    struct Summary: Equatable {
        let groupCount: Int
        let groupedCount: Int
        let largestGroupSize: Int
        let removableCount: Int
    }

    /// 时间上相邻的下标对：每个下标只与其后最多 `maximumNeighbors` 个、且拍摄时间差不超过
    /// `windowSeconds` 的下标配对。`times` 须按升序传入。
    static func neighborIndexPairs(
        times: [Double],
        maximumNeighbors: Int,
        windowSeconds: Double
    ) -> [(Int, Int)] {
        var pairs: [(Int, Int)] = []
        guard maximumNeighbors > 0 else {
            return pairs
        }
        for first in times.indices {
            var taken = 0
            var second = first + 1
            while second < times.count, taken < maximumNeighbors {
                if times[second] - times[first] > windowSeconds {
                    break
                }
                pairs.append((first, second))
                taken += 1
                second += 1
            }
        }
        return pairs
    }

    /// 并查集分组：距离 **小于等于** 阈值连边，取连通分量，只留 >= 2 张的组。
    /// 组内下标升序、组按首元素升序；越界下标的对忽略。
    static func groups(
        itemCount: Int,
        pairs: [(Int, Int, Double)],
        threshold: Double
    ) -> [[Int]] {
        guard itemCount > 0 else {
            return []
        }
        var parent = Array(0..<itemCount)
        func root(_ value: Int) -> Int {
            var current = value
            while parent[current] != current {
                parent[current] = parent[parent[current]]
                current = parent[current]
            }
            return current
        }
        for pair in pairs {
            guard pair.0 >= 0, pair.0 < itemCount,
                  pair.1 >= 0, pair.1 < itemCount,
                  pair.2 <= threshold else {
                continue
            }
            let left = root(pair.0)
            let right = root(pair.1)
            if left != right {
                parent[right] = left
            }
        }
        var members: [Int: [Int]] = [:]
        for index in 0..<itemCount {
            members[root(index), default: []].append(index)
        }
        let grouped = members.values
            .filter { $0.count >= 2 }
            .map { $0.sorted() }
        return grouped.sorted { left, right in
            (left.first ?? 0) < (right.first ?? 0)
        }
    }

    static func summary(groups: [[Int]]) -> Summary {
        let groupedCount = groups.reduce(into: 0) { total, group in
            total += group.count
        }
        let largest = groups.map { $0.count }.max() ?? 0
        let removable = groups.reduce(into: 0) { total, group in
            total += max(0, group.count - 1)
        }
        return Summary(
            groupCount: groups.count,
            groupedCount: groupedCount,
            largestGroupSize: largest,
            removableCount: removable
        )
    }
}

/// 取消令牌（探针形状）：`NSLock` 保护的布尔。
final class S0SimilarCancellationToken {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        return cancelled
    }

    func cancel() {
        lock.lock()
        defer {
            lock.unlock()
        }
        cancelled = true
    }
}

/// 识别阶段（诊断文本的 `state=`）。
enum S0SimilarRecognitionState: String {
    case idle
    case running
    case done
}

/// 一次识别的结果。只进扫描服务的状态与诊断文本，本卡不进快照。
struct S0SimilarRecognitionResult: Equatable, Sendable {
    let candidateCount: Int
    let reusedCount: Int
    let extractedCount: Int
    let inCloudCount: Int
    let failedCount: Int
    let revision: Int
    let pairCount: Int
    let distanceFailedCount: Int
    /// 每组成员的 `localIdentifier`，组内按拍摄时间升序（同刻按标识升序）、组按首成员升序。
    let groups: [[String]]
    let extractionSeconds: Double
    let groupingMilliseconds: Double
    let cacheWriteFailed: Bool
    let cancelled: Bool

    static let idle = S0SimilarRecognitionResult(
        candidateCount: 0, reusedCount: 0, extractedCount: 0, inCloudCount: 0, failedCount: 0,
        revision: 0, pairCount: 0, distanceFailedCount: 0, groups: [], extractionSeconds: 0,
        groupingMilliseconds: 0, cacheWriteFailed: false, cancelled: false
    )

    var summary: S0SimilarPhotosGrouping.Summary {
        let sizes = groups.map { $0.count }
        return S0SimilarPhotosGrouping.Summary(
            groupCount: groups.count,
            groupedCount: sizes.reduce(0, +),
            largestGroupSize: sizes.max() ?? 0,
            removableCount: sizes.reduce(0) { $0 + max(0, $1 - 1) }
        )
    }
}

/// 汇集容器（陷阱 10）：并发填充只做无序汇总，取用时按下标读。
private final class S0SimilarPrintCollector {
    private let lock = NSLock()
    private var prints: [Int: S0FeaturePrint] = [:]
    private var inCloud = 0
    private var failed = 0
    private var extracted = 0

    func store(_ outcome: S0FeaturePrintOutcome, at index: Int) {
        lock.lock()
        defer {
            lock.unlock()
        }
        switch outcome {
        case let .extracted(featurePrint):
            prints[index] = featurePrint
            extracted += 1
        case .inCloud:
            inCloud += 1
        case .failed:
            failed += 1
        }
    }

    func storeReused(_ featurePrint: S0FeaturePrint, at index: Int) {
        lock.lock()
        defer {
            lock.unlock()
        }
        prints[index] = featurePrint
    }

    var snapshot: (prints: [Int: S0FeaturePrint], inCloud: Int, failed: Int, extracted: Int) {
        lock.lock()
        defer {
            lock.unlock()
        }
        return (prints, inCloud, failed, extracted)
    }
}

/// IC-175：相似照片识别器。
///
/// 在自己的 GCD 并发队列上跑（探针裁定 一：同步取图不进 Swift 协作线程池、不用 `TaskGroup`）；
/// 调用方（扫描服务的一遍）只等完成回调。每次识别：
/// 1. 候选按拍摄时间升序、同刻按标识升序排定（结果确定）；
/// 2. 读特征缓存，`modificationDate` 与 revision 都相同且解档成功的直接复用；
/// 3. 其余经 `extract` 闭包并发提取（并发 `featureConcurrency`，信号量限流）；
/// 4. 缓存整份重写一次（只含本次候选里拿到印象的条目，库内已无的条目随之丢弃）；
/// 5. 相邻对距离顺序算、并查集分组，完成回调带结果。
/// 取消：逐张检查令牌；取消后不再发起新提取，已拿到的印象照常入缓存，结果标 `cancelled`。
final class S0SimilarPhotosRecognizer {
    private let queue = DispatchQueue(
        label: "photocleanup.s0.similar-features",
        qos: .utility,
        attributes: .concurrent
    )
    private let cacheStore: S0SimilarFeatureCacheStore?

    /// `cacheStore` 为 nil 即不持久化（测试用）。
    init(cacheStore: S0SimilarFeatureCacheStore?) {
        self.cacheStore = cacheStore
    }

    /// 当前系统默认的特征 revision（产品路径）。
    static func currentRevision() -> Int {
        VNGenerateImageFeaturePrintRequest().revision
    }

    static func orderedCandidates(_ candidates: [S0SimilarCandidate]) -> [S0SimilarCandidate] {
        candidates.sorted { lhs, rhs in
            if lhs.creationTime != rhs.creationTime {
                return lhs.creationTime < rhs.creationTime
            }
            return lhs.id < rhs.id
        }
    }

    func recognize(
        candidates: [S0SimilarCandidate],
        revision: Int,
        extract: @escaping (String) -> S0FeaturePrintOutcome,
        cancellation: S0SimilarCancellationToken,
        completion: @escaping (S0SimilarRecognitionResult) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                completion(.idle)
                return
            }
            completion(self.perform(
                candidates: candidates,
                revision: revision,
                extract: extract,
                cancellation: cancellation
            ))
        }
    }

    private func perform(
        candidates: [S0SimilarCandidate],
        revision: Int,
        extract: @escaping (String) -> S0FeaturePrintOutcome,
        cancellation: S0SimilarCancellationToken
    ) -> S0SimilarRecognitionResult {
        let ordered = Self.orderedCandidates(candidates)
        let cached = cacheStore?.load() ?? [:]
        let collector = S0SimilarPrintCollector()
        var reused = 0
        var toExtract: [Int] = []
        for (index, candidate) in ordered.enumerated() {
            if let entry = cached[candidate.id],
               entry.revision == revision,
               entry.modificationDate == candidate.modificationDate,
               let featurePrint = S0FeaturePrint.unarchived(entry.archive) {
                collector.storeReused(featurePrint, at: index)
                reused += 1
            } else {
                toExtract.append(index)
            }
        }

        let extractionStart = Date()
        let semaphore = DispatchSemaphore(value: max(1, S0SimilarPhotosRules.featureConcurrency))
        let group = DispatchGroup()
        for index in toExtract {
            guard !cancellation.isCancelled else {
                break
            }
            let identifier = ordered[index].id
            semaphore.wait()
            group.enter()
            queue.async {
                defer {
                    semaphore.signal()
                    group.leave()
                }
                collector.store(extract(identifier), at: index)
            }
        }
        group.wait()
        let extractionSeconds = Date().timeIntervalSince(extractionStart)
        let gathered = collector.snapshot

        var cacheWriteFailed = false
        if let cacheStore {
            var entries: [String: S0SimilarFeatureCacheEntry] = [:]
            for (index, featurePrint) in gathered.prints {
                let candidate = ordered[index]
                if let existing = cached[candidate.id],
                   existing.revision == revision,
                   existing.modificationDate == candidate.modificationDate {
                    entries[candidate.id] = existing
                } else if let archive = featurePrint.archived() {
                    entries[candidate.id] = S0SimilarFeatureCacheEntry(
                        modificationDate: candidate.modificationDate,
                        revision: revision,
                        archive: archive
                    )
                }
            }
            if entries != cached {
                do {
                    try cacheStore.save(entries)
                } catch {
                    cacheWriteFailed = true
                }
            }
        }

        let groupingStart = Date()
        let times = ordered.map { $0.creationTime }
        let indexPairs = S0SimilarPhotosGrouping.neighborIndexPairs(
            times: times,
            maximumNeighbors: S0SimilarPhotosRules.neighborWindowCount,
            windowSeconds: S0SimilarPhotosRules.neighborWindowSeconds
        )
        var distancePairs: [(Int, Int, Double)] = []
        distancePairs.reserveCapacity(indexPairs.count)
        var distanceFailed = 0
        for pair in indexPairs {
            guard let first = gathered.prints[pair.0], let second = gathered.prints[pair.1] else {
                continue
            }
            if let distance = first.distance(to: second) {
                distancePairs.append((pair.0, pair.1, distance))
            } else {
                distanceFailed += 1
            }
        }
        let indexGroups = S0SimilarPhotosGrouping.groups(
            itemCount: ordered.count,
            pairs: distancePairs,
            threshold: S0SimilarPhotosRules.distanceThreshold
        )
        let groups = indexGroups.map { group in
            group.map { ordered[$0].id }
        }
        let groupingMilliseconds = Date().timeIntervalSince(groupingStart) * 1_000

        return S0SimilarRecognitionResult(
            candidateCount: ordered.count,
            reusedCount: reused,
            extractedCount: gathered.extracted,
            inCloudCount: gathered.inCloud,
            failedCount: gathered.failed,
            revision: revision,
            pairCount: distancePairs.count,
            distanceFailedCount: distanceFailed,
            groups: groups,
            extractionSeconds: extractionSeconds,
            groupingMilliseconds: groupingMilliseconds,
            cacheWriteFailed: cacheWriteFailed,
            cancelled: cancellation.isCancelled
        )
    }
}

/// 诊断文本（全 ASCII，照 IC-168 的形状），供 S2 标定面板末段复制。
enum S0SimilarDiagnosticsText {
    static let format = "format=ic175-similar-v1"

    static func lines(state: String, result: S0SimilarRecognitionResult) -> [String] {
        let summary = result.summary
        let counts: [String] = [
            "candidates=" + String(result.candidateCount),
            "reused=" + String(result.reusedCount),
            "extracted=" + String(result.extractedCount),
            "in_cloud=" + String(result.inCloudCount),
            "failed=" + String(result.failedCount),
            "revision=" + String(result.revision)
        ]
        let pairs: [String] = [
            "pairs=" + String(result.pairCount),
            "distance_failed=" + String(result.distanceFailedCount),
            "threshold=" + fixed(S0SimilarPhotosRules.distanceThreshold),
            "window=" + String(S0SimilarPhotosRules.neighborWindowCount) + "/" + String(Int(S0SimilarPhotosRules.neighborWindowSeconds))
        ]
        let groups: [String] = [
            "groups=" + String(summary.groupCount),
            "grouped=" + String(summary.groupedCount),
            "largest=" + String(summary.largestGroupSize),
            "removable=" + String(summary.removableCount)
        ]
        let cacheWrite = result.cacheWriteFailed ? "failed" : "ok"
        let cancelled = result.cancelled ? "1" : "0"
        let timing: [String] = [
            "extract_seconds=" + fixed(result.extractionSeconds),
            "group_ms=" + String(Int(result.groupingMilliseconds.rounded())),
            "cache_write=" + cacheWrite,
            "cancelled=" + cancelled
        ]
        return [
            format,
            "state=" + state,
            counts.joined(separator: " "),
            pairs.joined(separator: " "),
            groups.joined(separator: " "),
            timing.joined(separator: " ")
        ]
    }

    static func text(state: String, result: S0SimilarRecognitionResult) -> String {
        lines(state: state, result: result).joined(separator: "\n")
    }

    private static func fixed(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

/// 生产取图 + Vision 特征提取（探针 `SimilarPhotosImageFetch.fetch` 与 `measureOne` 的形状）：
/// 同步、禁网络、长边 `featureTargetSide`、`aspectFit`；`image == nil` 时按
/// `PHImageResultIsInCloudKey` 分 iCloud 未下载与失败。复用一遍枚举留存的 `PHAsset`，不按标识
/// 再查库（IC155 断言对服务文件的钉子）；查不到即失败。
extension S0PhotoKitScanLibrary {
    func extractFeaturePrint(for identifier: String) -> S0FeaturePrintOutcome {
        guard let asset = cachedAsset(for: identifier) else {
            return .failed
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false

        var image: UIImage?
        var info: [AnyHashable: Any]?
        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(
                width: S0SimilarPhotosRules.featureTargetSide,
                height: S0SimilarPhotosRules.featureTargetSide
            ),
            contentMode: .aspectFit,
            options: options
        ) { result, resultInfo in
            image = result
            info = resultInfo
        }
        guard let cgImage = image?.cgImage else {
            if (info?[PHImageResultIsInCloudKey] as? Bool) == true {
                return .inCloud
            }
            return .failed
        }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failed
        }
        let results: [Any] = request.results ?? []
        guard let observation = results.first as? VNFeaturePrintObservation else {
            return .failed
        }
        return .extracted(S0FeaturePrint(observation: observation))
    }
}
