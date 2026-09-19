import Foundation
import Photos
import UIKit
import Vision
import os

/// IC-161：相似照片探针的取数实现与报告文本。**探针专用，不参与任何产品路径。**
///
/// 形状照 IC-099b 字节数探针与 IC-145 扫描服务探针：协调器只在面板按钮显式触发时才取数，
/// 关闭态零副作用（不注册观察者、不持有取数实现、不发请求、不写持久化）；全部 PhotoKit
/// 请求禁网络；报告文本是纯函数、全 ASCII，便于复制回来逐字对读。
///
/// 并发口径（任务卡裁定 一，写死）：取图与特征计算跑在本文件私有的并发队列上，用
/// `DispatchSemaphore` 限流；**不用 `TaskGroup`、不把同步 PhotoKit 请求放进 `Task`**
/// （同步请求会阻塞调用线程，放进协作线程池会把别的任务饿死）；结果容器加锁且只做
/// 顺序无关的汇总（陷阱 10）；进度与最终报告只经主队列单点回写。

// MARK: - 样本上限

/// 面板选择器的样本上限。`all` 表示不截断。
enum SimilarPhotosSampleLimit: CaseIterable, Identifiable, Equatable {
    case fiveHundred
    case twoThousand
    case all

    var id: Int {
        maximumCount ?? 0
    }

    /// 上限张数；`nil` 表示全部。
    var maximumCount: Int? {
        switch self {
        case .fiveHundred:
            return 500
        case .twoThousand:
            return 2_000
        case .all:
            return nil
        }
    }

    /// 选择器上的纯数字标签；`nil` 的那一档用目录文案「全部」。
    var digitsLabel: String? {
        maximumCount.map { String($0) }
    }
}

// MARK: - 环境量

/// 开始与结束各读一次的环境量。**一律在主线程读**（电量与可用内存都要求主线程）。
struct SimilarPhotosEnvironmentSample: Equatable {
    /// `ProcessInfo.ThermalState` 的 rawValue。
    let thermalRawValue: Int
    /// 电量百分比；负值表示未知（刚打开监听时常见）。
    let batteryPercent: Int
    /// `os_proc_available_memory()`；模拟器上恒 0。
    let availableMemoryBytes: Int

    static func current() -> SimilarPhotosEnvironmentSample {
        let level = UIDevice.current.batteryLevel
        let percent = level < 0 ? -1 : Int((level * 100).rounded())
        return SimilarPhotosEnvironmentSample(
            thermalRawValue: ProcessInfo.processInfo.thermalState.rawValue,
            batteryPercent: percent,
            availableMemoryBytes: Int(os_proc_available_memory())
        )
    }
}

// MARK: - 逐张测量

/// 单张的结局。取图拿不到图时按 `info[PHImageResultIsInCloudKey]` 分两类。
enum SimilarPhotosFeatureOutcome: Equatable {
    case ok
    case inCloud
    case failed
}

/// 单张的耗时与结局。特征本身不进这里——它随块释放，不常驻内存。
struct SimilarPhotosFeatureMeasurement: Equatable {
    let fetchMilliseconds: Double
    let visionMilliseconds: Double
    let outcome: SimilarPhotosFeatureOutcome
}

/// 一次特征提取运行的全部产出。
struct SimilarPhotosFeatureProbeResult {
    let libraryImageCount: Int
    let screenshotCount: Int
    let sampledCount: Int
    let enumerateMilliseconds: Double
    let revision: Int
    let concurrency: Int
    let measurements: [SimilarPhotosFeatureMeasurement]
    let printElementCount: Int?
    let printElementTypeRawValue: Int?
    let printByteCount: Int?
    let wallClockSeconds: Double
    let memoryMinimumBytes: Int
    let cancelled: Bool
    /// IC-161 B：时间上相邻的成对距离（下标、下标、距离）。随运行留在内存里，不写缓存。
    let neighborPairs: [(Int, Int, Double)]
    /// `computeDistance` 抛错的对数（例如两张的特征版本不一致）。
    let distanceFailedCount: Int
    /// 样本的资产标识，按时间升序；分组段的肉眼核对列表按下标取缩略图。
    let sampleAssetIDs: [String]
}

// MARK: - 纯函数：分位数与外推

/// 分位数、均值与外推。纯函数，测试直接断言。
enum SimilarPhotosProbeMath {
    /// 最近秩分位数。`percent` 取 **整数百分比**（0…100）——小数百分比乘以样本数在双精度下
    /// 会多出末位（`0.1 * 30 == 3.0000000000000004`），向上取整就多一位。
    static func percentile(_ values: [Double], percent: Int) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        let sorted = values.sorted()
        let count = sorted.count
        let clamped = min(100, max(0, percent))
        let rank = min(count, max(1, (clamped * count + 99) / 100))
        return sorted[rank - 1]
    }

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        let total = values.reduce(into: Double(0)) { sum, value in
            sum += value
        }
        return total / Double(values.count)
    }

    static func maximum(_ values: [Double]) -> Double? {
        values.max()
    }

    /// 串行上界：单张平均总耗时 × 全库待测张数。
    static func extrapolatedSerialSeconds(
        meanFetchMilliseconds: Double,
        meanVisionMilliseconds: Double,
        totalCount: Int
    ) -> Double {
        let perAsset = meanFetchMilliseconds + meanVisionMilliseconds
        return perAsset * Double(totalCount) / 1_000
    }

    /// 实测吞吐（成功张数 ÷ 墙钟秒）。
    static func throughputPerSecond(
        okCount: Int,
        wallClockSeconds: Double
    ) -> Double? {
        guard wallClockSeconds > 0, okCount > 0 else {
            return nil
        }
        return Double(okCount) / wallClockSeconds
    }

    /// 按实测吞吐外推全库耗时。**不做「÷ 并发度」的理想化外推**（裁定 二）。
    static func extrapolatedSecondsAtThroughput(
        totalCount: Int,
        throughputPerSecond: Double
    ) -> Double? {
        guard throughputPerSecond > 0 else {
            return nil
        }
        return Double(totalCount) / throughputPerSecond
    }
}

// MARK: - 纯函数：ASCII 报告文本

/// 报告文本的共用零件。**全 ASCII**：报告要被复制回聊天里逐字对读。
enum SimilarPhotosProbeFormat {
    static let newline = String(Character(UnicodeScalar(UInt8(10))))
    static let unknownText = "unknown"

    static func thermalName(_ rawValue: Int) -> String {
        let names = ["nominal", "fair", "serious", "critical"]
        let index = min(max(0, rawValue), names.count - 1)
        return names[index]
    }

    static func batteryText(_ percent: Int) -> String {
        guard percent >= 0 else {
            return unknownText
        }
        return String(percent)
    }

    static func decimal(_ value: Double, digits: Int = 3) -> String {
        String(format: "%.\(digits)f", value)
    }

    static func optionalDecimal(_ value: Double?, digits: Int = 3) -> String {
        guard let value else {
            return unknownText
        }
        return decimal(value, digits: digits)
    }

    static func optionalInteger(_ value: Int?) -> String {
        guard let value else {
            return unknownText
        }
        return String(value)
    }

    /// `name p50=… p90=… max=… mean=…` 一行。
    static func statisticsLine(name: String, values: [Double]) -> String {
        let parts = [
            name,
            "p50=" + optionalDecimal(SimilarPhotosProbeMath.percentile(values, percent: 50)),
            "p90=" + optionalDecimal(SimilarPhotosProbeMath.percentile(values, percent: 90)),
            "max=" + optionalDecimal(SimilarPhotosProbeMath.maximum(values)),
            "mean=" + optionalDecimal(SimilarPhotosProbeMath.mean(values))
        ]
        return parts.joined(separator: " ")
    }
}

/// 特征提取段的报告文本。纯函数，测试直接断言。
enum SimilarPhotosFeatureProbeText {
    static let formatIdentifier = "ic161-feature-v1"
    static let targetLongSide = 360

    static func progress(finished: Int, total: Int) -> String {
        let text = String(finished) + "/" + String(total)
        return text
    }

    static func report(
        result: SimilarPhotosFeatureProbeResult,
        environmentStart: SimilarPhotosEnvironmentSample,
        environmentEnd: SimilarPhotosEnvironmentSample
    ) -> String {
        let fetchValues = result.measurements
            .filter { $0.outcome == .ok }
            .map { $0.fetchMilliseconds }
        let visionValues = result.measurements
            .filter { $0.outcome == .ok }
            .map { $0.visionMilliseconds }
        let okCount = result.measurements.filter { $0.outcome == .ok }.count
        let inCloudCount = result.measurements.filter { $0.outcome == .inCloud }.count
        let failedCount = result.measurements.filter { $0.outcome == .failed }.count
        let pendingCount = result.libraryImageCount - result.screenshotCount
        let throughput = SimilarPhotosProbeMath.throughputPerSecond(
            okCount: okCount,
            wallClockSeconds: result.wallClockSeconds
        )
        let meanFetch = SimilarPhotosProbeMath.mean(fetchValues) ?? 0
        let meanVision = SimilarPhotosProbeMath.mean(visionValues) ?? 0
        let serialSeconds = SimilarPhotosProbeMath.extrapolatedSerialSeconds(
            meanFetchMilliseconds: meanFetch,
            meanVisionMilliseconds: meanVision,
            totalCount: pendingCount
        )
        let throughputSeconds = throughput.flatMap { value in
            SimilarPhotosProbeMath.extrapolatedSecondsAtThroughput(
                totalCount: pendingCount,
                throughputPerSecond: value
            )
        }
        let extrapolatedPrintBytes = result.printByteCount.map { $0 * pendingCount }

        var lines: [String] = []
        lines.append("format=" + formatIdentifier)
        lines.append("cancelled=" + String(result.cancelled))
        lines.append(
            [
                "library_images=" + String(result.libraryImageCount),
                "screenshots_excluded=" + String(result.screenshotCount),
                "sampled=" + String(result.sampledCount),
                "enumerate_ms=" + SimilarPhotosProbeFormat.decimal(result.enumerateMilliseconds)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "revision=" + String(result.revision),
                "concurrency=" + String(result.concurrency),
                "target_long_side=" + String(targetLongSide),
                "chunk=" + String(SimilarPhotosProbeLimits.chunkSize)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "thermal_start=" + SimilarPhotosProbeFormat.thermalName(environmentStart.thermalRawValue),
                "thermal_end=" + SimilarPhotosProbeFormat.thermalName(environmentEnd.thermalRawValue)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "battery_start=" + SimilarPhotosProbeFormat.batteryText(environmentStart.batteryPercent),
                "battery_end=" + SimilarPhotosProbeFormat.batteryText(environmentEnd.batteryPercent)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "mem_available_start=" + String(environmentStart.availableMemoryBytes),
                "mem_available_end=" + String(environmentEnd.availableMemoryBytes),
                "mem_available_min=" + String(result.memoryMinimumBytes)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "print_element_count=" + SimilarPhotosProbeFormat.optionalInteger(result.printElementCount),
                "print_element_type=" + SimilarPhotosProbeFormat.optionalInteger(result.printElementTypeRawValue),
                "print_bytes=" + SimilarPhotosProbeFormat.optionalInteger(result.printByteCount)
            ].joined(separator: " ")
        )
        lines.append(
            SimilarPhotosProbeFormat.statisticsLine(name: "fetch_ms", values: fetchValues)
        )
        lines.append(
            SimilarPhotosProbeFormat.statisticsLine(name: "vision_ms", values: visionValues)
        )
        lines.append(
            [
                "ok=" + String(okCount),
                "in_cloud=" + String(inCloudCount),
                "failed=" + String(failedCount)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "wall_clock_s=" + SimilarPhotosProbeFormat.decimal(result.wallClockSeconds),
                "throughput=" + SimilarPhotosProbeFormat.optionalDecimal(throughput)
            ].joined(separator: " ")
        )
        lines.append("pending_images=" + String(pendingCount))
        lines.append(
            "extrapolated_serial_s=" + SimilarPhotosProbeFormat.decimal(serialSeconds)
        )
        lines.append(
            "extrapolated_at_measured_throughput_s="
                + SimilarPhotosProbeFormat.optionalDecimal(throughputSeconds)
        )
        lines.append(
            "extrapolated_print_bytes="
                + SimilarPhotosProbeFormat.optionalInteger(extrapolatedPrintBytes)
        )
        return lines.joined(separator: SimilarPhotosProbeFormat.newline)
    }
}

// MARK: - 纯函数：相邻对、直方图与分组

/// 相邻对生成、距离直方图与并查集分组（裁定 三）。纯函数，测试直接断言。
enum SimilarPhotosGrouping {
    /// 分组汇总。
    struct Summary: Equatable {
        let groupCount: Int
        let groupedCount: Int
        let largestGroupSize: Int
        let removableCount: Int
    }

    /// 时间上相邻的下标对：每个下标只与其后最多 `maximumNeighbors` 个、且拍摄时间差不超过
    /// `windowSeconds` 的下标配对。`times` 须按升序传入（样本本来就按拍摄时间升序）。
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

    /// 距离直方图。**先乘后取整**：`Int((value * 1000).rounded()) / bucketMilliWidth`——
    /// 写成 `Int(value / 0.05)` 在双精度下会把 0.30、0.15、0.60、0.70 落到前一档
    /// （`0.30 / 0.05 == 5.999...`）。返回 `bucketCount + 1` 个计数，末位是溢出档。
    static func histogram(
        values: [Double],
        bucketMilliWidth: Int,
        bucketCount: Int
    ) -> [Int] {
        let count = max(1, bucketCount)
        var buckets = [Int](repeating: 0, count: count + 1)
        guard bucketMilliWidth > 0 else {
            return buckets
        }
        for value in values {
            let milli = max(0, Int((value * 1_000).rounded()))
            let index = milli / bucketMilliWidth
            if index >= count {
                buckets[count] += 1
            } else {
                buckets[index] += 1
            }
        }
        return buckets
    }

    /// 实测 max 超出 40 档时把档宽放大到 max 的 1/40（旧版 revision 的距离是几十的量级）。
    static func bucketMilliWidth(forMaximum maximum: Double) -> Int {
        let standard = SimilarPhotosProbeLimits.histogramBucketMilliWidth
        let count = SimilarPhotosProbeLimits.histogramBucketCount
        let maximumMilli = Int((maximum * 1_000).rounded())
        guard maximumMilli > standard * count else {
            return standard
        }
        let widened = (maximumMilli + count - 1) / count
        return max(standard, widened)
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

    /// 肉眼核对列表：按组大小降序（同大小按首元素升序）取前 `limit` 组。
    static func previewGroups(_ groups: [[Int]], limit: Int) -> [[Int]] {
        let ordered = groups.sorted { left, right in
            if left.count != right.count {
                return left.count > right.count
            }
            return (left.first ?? 0) < (right.first ?? 0)
        }
        return Array(ordered.prefix(max(0, limit)))
    }
}

/// 分组段的报告文本。纯函数，测试直接断言；全 ASCII。
enum SimilarPhotosGroupingProbeText {
    static let formatIdentifier = "ic161-grouping-v1"

    static func report(
        pairs: [(Int, Int, Double)],
        distanceFailedCount: Int,
        sampleCount: Int
    ) -> String {
        let distances = pairs.map { $0.2 }
        let milliWidth = SimilarPhotosGrouping.bucketMilliWidth(
            forMaximum: distances.max() ?? 0
        )
        let buckets = SimilarPhotosGrouping.histogram(
            values: distances,
            bucketMilliWidth: milliWidth,
            bucketCount: SimilarPhotosProbeLimits.histogramBucketCount
        )
        var lines: [String] = []
        lines.append("format=" + formatIdentifier)
        lines.append(
            [
                "sampled=" + String(sampleCount),
                "pairs=" + String(pairs.count),
                "distance_failed=" + String(distanceFailedCount)
            ].joined(separator: " ")
        )
        lines.append(
            [
                "window_neighbors=" + String(SimilarPhotosProbeLimits.windowNeighbors),
                "window_seconds=" + String(Int(SimilarPhotosProbeLimits.windowSeconds)),
                "chunk=" + String(SimilarPhotosProbeLimits.chunkSize)
            ].joined(separator: " ")
        )
        lines.append(distanceLine(distances))
        lines.append(
            [
                "histogram bucket_milli=" + String(milliWidth),
                "counts=" + buckets.map { String($0) }.joined(separator: ",")
            ].joined(separator: " ")
        )
        for threshold in SimilarPhotosProbeLimits.thresholdOptions {
            let summary = SimilarPhotosGrouping.summary(
                groups: SimilarPhotosGrouping.groups(
                    itemCount: sampleCount,
                    pairs: pairs,
                    threshold: threshold
                )
            )
            lines.append(
                [
                    "threshold=" + SimilarPhotosProbeFormat.decimal(threshold, digits: 2),
                    "groups=" + String(summary.groupCount),
                    "grouped=" + String(summary.groupedCount),
                    "largest=" + String(summary.largestGroupSize),
                    "removable=" + String(summary.removableCount)
                ].joined(separator: " ")
            )
        }
        return lines.joined(separator: SimilarPhotosProbeFormat.newline)
    }

    static func distanceLine(_ distances: [Double]) -> String {
        let parts = [
            "distance",
            "min=" + SimilarPhotosProbeFormat.optionalDecimal(distances.min()),
            "p10=" + SimilarPhotosProbeFormat.optionalDecimal(
                SimilarPhotosProbeMath.percentile(distances, percent: 10)
            ),
            "p50=" + SimilarPhotosProbeFormat.optionalDecimal(
                SimilarPhotosProbeMath.percentile(distances, percent: 50)
            ),
            "p90=" + SimilarPhotosProbeFormat.optionalDecimal(
                SimilarPhotosProbeMath.percentile(distances, percent: 90)
            ),
            "max=" + SimilarPhotosProbeFormat.optionalDecimal(distances.max())
        ]
        return parts.joined(separator: " ")
    }
}

// MARK: - 探针常量

/// 探针自己的上限常量。不是产品取值，不进 `S2CalibrationConfiguration`。
enum SimilarPhotosProbeLimits {
    /// 分块大小：块内并发算特征，块算完即释放，特征不常驻内存。
    static let chunkSize = 64
    /// 取图目标边长。
    static let targetSide: CGFloat = 360
    /// 面板并发度选择器的取值。
    static let concurrencyOptions = [1, 2, 4]
    /// 只比时间上相邻的照片：每张最多与其后 12 张比，且拍摄时间差不超过 600 s（裁定 三）。
    static let windowNeighbors = 12
    static let windowSeconds: Double = 600
    /// 距离直方图：档宽 0.05（毫单位 50）、40 档 + 一个溢出档。
    static let histogramBucketMilliWidth = 50
    static let histogramBucketCount = 40
    /// 肉眼核对列表：按组大小降序取前 30 组，每组先列 10 张。
    static let previewGroupLimit = 30
    static let previewThumbnailLimit = 10
    /// 面板阈值选择器的七档。
    static let thresholdOptions: [Double] = [0.20, 0.30, 0.40, 0.50, 0.60, 0.70, 0.80]
}

// MARK: - 取数接口与协调器

/// 取数接口。产品侧只有调试面板按钮会调用它；PhotoKit + Vision 实现在本文件下方。
protocol SimilarPhotosFeatureProbing: AnyObject {
    func measure(
        limit: SimilarPhotosSampleLimit,
        concurrency: Int,
        cancellation: SimilarPhotosCancellationToken,
        progress: @escaping (Int, Int) -> Void,
        memorySample: @escaping () -> Int,
        completion: @escaping (SimilarPhotosFeatureProbeResult) -> Void
    )
}

/// 取消标志。加锁，跨线程读写。
final class SimilarPhotosCancellationToken {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        cancelled = false
    }
}

/// 特征提取探针的协调器。只有面板按钮显式 `run` 才开始；可取消；不写任何持久化。
final class SimilarPhotosFeatureProbeCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var progressText = ""
    @Published private(set) var reportText = ""

    /// 本次运行的样本标识，供分组段的肉眼核对列表取缩略图。关 App 即丢，不写缓存。
    private(set) var sampleAssetIDs: [String] = []
    /// IC-161 B：时间上相邻的成对距离。分组段只对它做纯函数重算，自己不取数。
    private(set) var neighborPairs: [(Int, Int, Double)] = []
    @Published private(set) var groupingReportText = ""

    private let cancellation = SimilarPhotosCancellationToken()
    private var environmentStart = SimilarPhotosEnvironmentSample(
        thermalRawValue: 0,
        batteryPercent: -1,
        availableMemoryBytes: 0
    )
    private var batteryMonitoringWasEnabled = false

    var canExport: Bool {
        !isRunning && !reportText.isEmpty
    }

    func run(
        limit: SimilarPhotosSampleLimit,
        concurrency: Int,
        using prober: SimilarPhotosFeatureProbing
    ) {
        guard !isRunning else {
            return
        }
        isRunning = true
        reportText = ""
        groupingReportText = ""
        sampleAssetIDs = []
        neighborPairs = []
        progressText = SimilarPhotosFeatureProbeText.progress(finished: 0, total: 0)
        cancellation.reset()
        batteryMonitoringWasEnabled = UIDevice.current.isBatteryMonitoringEnabled
        UIDevice.current.isBatteryMonitoringEnabled = true
        // 电量在打开监听之后隔一次主队列派发再读，否则常得 -1（裁定 二）。
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.environmentStart = SimilarPhotosEnvironmentSample.current()
            self.start(limit: limit, concurrency: concurrency, using: prober)
        }
    }

    func cancel() {
        cancellation.cancel()
    }

    private func start(
        limit: SimilarPhotosSampleLimit,
        concurrency: Int,
        using prober: SimilarPhotosFeatureProbing
    ) {
        prober.measure(
            limit: limit,
            concurrency: concurrency,
            cancellation: cancellation,
            progress: { [weak self] finished, total in
                DispatchQueue.main.async {
                    self?.progressText = SimilarPhotosFeatureProbeText.progress(
                        finished: finished,
                        total: total
                    )
                }
            },
            memorySample: {
                // 可用内存要求主线程读；采样点在后台，故同步回主队列取一次。
                var bytes = 0
                DispatchQueue.main.sync {
                    bytes = SimilarPhotosEnvironmentSample.current().availableMemoryBytes
                }
                return bytes
            },
            completion: { [weak self] result in
                self?.finish(with: result)
            }
        )
    }

    private func finish(with result: SimilarPhotosFeatureProbeResult) {
        let environmentEnd = SimilarPhotosEnvironmentSample.current()
        UIDevice.current.isBatteryMonitoringEnabled = batteryMonitoringWasEnabled
        reportText = SimilarPhotosFeatureProbeText.report(
            result: result,
            environmentStart: environmentStart,
            environmentEnd: environmentEnd
        )
        sampleAssetIDs = result.sampleAssetIDs
        neighborPairs = result.neighborPairs
        groupingReportText = SimilarPhotosGroupingProbeText.report(
            pairs: result.neighborPairs,
            distanceFailedCount: result.distanceFailedCount,
            sampleCount: result.sampleAssetIDs.count
        )
        isRunning = false
        progressText = ""
    }
}

// MARK: - PhotoKit + Vision 实现

/// 逐张测量的汇总容器。并发填充，只做顺序无关的汇总（陷阱 10）。
private final class SimilarPhotosMeasurementCollector {
    private let lock = NSLock()
    private var measurements: [SimilarPhotosFeatureMeasurement] = []
    private var minimumMemoryBytes = Int.max
    private var firstPrint: (count: Int, typeRawValue: Int, bytes: Int)?
    private var observations: [Int: VNFeaturePrintObservation] = [:]
    private var pairs: [(Int, Int, Double)] = []
    private var distanceFailedCount = 0

    func append(_ measurement: SimilarPhotosFeatureMeasurement) {
        lock.lock()
        defer { lock.unlock() }
        measurements.append(measurement)
    }

    func notePrint(count: Int, typeRawValue: Int, bytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard firstPrint == nil else {
            return
        }
        firstPrint = (count, typeRawValue, bytes)
    }

    func storeObservation(_ observation: VNFeaturePrintObservation, at index: Int) {
        lock.lock()
        defer { lock.unlock() }
        observations[index] = observation
    }

    /// 取出仍在内存里的观测；块算完后只保留末尾若干个供跨块比对，其余随块释放。
    func observationPair(_ first: Int, _ second: Int) -> (
        VNFeaturePrintObservation,
        VNFeaturePrintObservation
    )? {
        lock.lock()
        defer { lock.unlock() }
        guard let left = observations[first], let right = observations[second] else {
            return nil
        }
        return (left, right)
    }

    func pruneObservations(keeping indices: Set<Int>) {
        lock.lock()
        defer { lock.unlock() }
        observations = observations.filter { indices.contains($0.key) }
    }

    func appendPair(_ pair: (Int, Int, Double)) {
        lock.lock()
        defer { lock.unlock() }
        pairs.append(pair)
    }

    func noteDistanceFailure() {
        lock.lock()
        defer { lock.unlock() }
        distanceFailedCount += 1
    }

    var pairSnapshot: (pairs: [(Int, Int, Double)], distanceFailedCount: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (pairs, distanceFailedCount)
    }

    func noteMemory(_ bytes: Int) {
        lock.lock()
        defer { lock.unlock() }
        minimumMemoryBytes = min(minimumMemoryBytes, bytes)
    }

    var finishedCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return measurements.count
    }

    var snapshot: (
        measurements: [SimilarPhotosFeatureMeasurement],
        minimumMemoryBytes: Int,
        printCount: Int?,
        printTypeRawValue: Int?,
        printBytes: Int?
    ) {
        lock.lock()
        defer { lock.unlock() }
        let memory = minimumMemoryBytes == Int.max ? 0 : minimumMemoryBytes
        return (
            measurements,
            memory,
            firstPrint?.count,
            firstPrint?.typeRawValue,
            firstPrint?.bytes
        )
    }
}

/// 相似照片特征提取的 PhotoKit + Vision 实现。
///
/// 只由 S2 调试面板的按钮触发，**不参与任何产品图片请求路径**。取图与特征都禁网络：
/// 不在本机的照片按 `PHImageResultIsInCloudKey` 计数后跳过，不下载。
final class SimilarPhotosFeatureProbeService: SimilarPhotosFeatureProbing {
    private let queue = DispatchQueue(
        label: "ic161.similar-photos.feature",
        qos: .utility,
        attributes: .concurrent
    )

    func measure(
        limit: SimilarPhotosSampleLimit,
        concurrency: Int,
        cancellation: SimilarPhotosCancellationToken,
        progress: @escaping (Int, Int) -> Void,
        memorySample: @escaping () -> Int,
        completion: @escaping (SimilarPhotosFeatureProbeResult) -> Void
    ) {
        queue.async { [weak self] in
            guard let self else {
                return
            }
            let result = self.performMeasurements(
                limit: limit,
                concurrency: concurrency,
                cancellation: cancellation,
                progress: progress,
                memorySample: memorySample
            )
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func performMeasurements(
        limit: SimilarPhotosSampleLimit,
        concurrency: Int,
        cancellation: SimilarPhotosCancellationToken,
        progress: @escaping (Int, Int) -> Void,
        memorySample: @escaping () -> Int
    ) -> SimilarPhotosFeatureProbeResult {
        let enumerateStart = Date()
        let inventory = SimilarPhotosFeatureProbeService.fetchCandidates()
        let enumerateMilliseconds = Date().timeIntervalSince(enumerateStart) * 1_000
        let sample = limit.maximumCount.map { Array(inventory.candidates.prefix($0)) }
            ?? inventory.candidates

        let sampleAssetIDs = sample.map { $0.localIdentifier }
        let times = sample.map { $0.creationDate?.timeIntervalSince1970 ?? 0 }
        // 只比时间上相邻的照片：下标对先一次算好（只是下标，不占内存），距离随块算。
        let indexPairs = SimilarPhotosGrouping.neighborIndexPairs(
            times: times,
            maximumNeighbors: SimilarPhotosProbeLimits.windowNeighbors,
            windowSeconds: SimilarPhotosProbeLimits.windowSeconds
        )
        var pairsBySecond: [Int: [Int]] = [:]
        for pair in indexPairs {
            pairsBySecond[pair.1, default: []].append(pair.0)
        }

        let collector = SimilarPhotosMeasurementCollector()
        let manager = PHImageManager.default()
        let semaphore = DispatchSemaphore(value: max(1, concurrency))
        let group = DispatchGroup()
        let runStart = Date()
        var processed = 0

        for chunkStart in stride(
            from: 0,
            to: sample.count,
            by: SimilarPhotosProbeLimits.chunkSize
        ) {
            guard !cancellation.isCancelled else {
                break
            }
            let chunkEnd = min(chunkStart + SimilarPhotosProbeLimits.chunkSize, sample.count)
            for index in chunkStart..<chunkEnd {
                guard !cancellation.isCancelled else {
                    break
                }
                let asset = sample[index]
                semaphore.wait()
                group.enter()
                queue.async {
                    defer {
                        semaphore.signal()
                        group.leave()
                    }
                    let outcome = SimilarPhotosFeatureProbeService.measureOne(
                        asset: asset,
                        manager: manager
                    )
                    collector.append(outcome.measurement)
                    if let observation = outcome.observation {
                        collector.storeObservation(observation, at: index)
                        collector.notePrint(
                            count: observation.elementCount,
                            typeRawValue: Int(observation.elementType.rawValue),
                            bytes: observation.data.count
                        )
                    }
                }
            }
            group.wait()
            // 块内并发算特征，块算完后**顺序**算该块涉及的相邻对距离（裁定 三）。
            for second in chunkStart..<chunkEnd {
                for first in pairsBySecond[second] ?? [] {
                    guard let observations = collector.observationPair(first, second) else {
                        continue
                    }
                    var value = Float(0)
                    do {
                        try observations.0.computeDistance(&value, to: observations.1)
                    } catch {
                        collector.noteDistanceFailure()
                        continue
                    }
                    collector.appendPair((first, second, Double(value)))
                }
            }
            // 只留本块末尾 12 个观测供跨块比对，其余随块释放：特征不常驻内存。
            let carryStart = max(chunkStart, chunkEnd - SimilarPhotosProbeLimits.windowNeighbors)
            collector.pruneObservations(keeping: Set(carryStart..<chunkEnd))
            processed = collector.finishedCount
            progress(processed, sample.count)
            // 每一块采一次可用内存，取最小值：特征随块释放，量到的才是提取的水位。
            collector.noteMemory(memorySample())
        }

        let wallClockSeconds = Date().timeIntervalSince(runStart)
        let snapshot = collector.snapshot
        let pairSnapshot = collector.pairSnapshot
        collector.pruneObservations(keeping: [])
        return SimilarPhotosFeatureProbeResult(
            libraryImageCount: inventory.libraryImageCount,
            screenshotCount: inventory.screenshotCount,
            sampledCount: sample.count,
            enumerateMilliseconds: enumerateMilliseconds,
            revision: VNGenerateImageFeaturePrintRequest().revision,
            concurrency: max(1, concurrency),
            measurements: snapshot.measurements,
            printElementCount: snapshot.printCount,
            printElementTypeRawValue: snapshot.printTypeRawValue,
            printByteCount: snapshot.printBytes,
            wallClockSeconds: wallClockSeconds,
            memoryMinimumBytes: snapshot.minimumMemoryBytes,
            cancelled: cancellation.isCancelled,
            neighborPairs: pairSnapshot.pairs,
            distanceFailedCount: pairSnapshot.distanceFailedCount,
            sampleAssetIDs: sampleAssetIDs
        )
    }

    /// 全库图片按拍摄时间升序取出，逐个剔掉截图（截图另有探针）。
    static func fetchCandidates() -> (
        libraryImageCount: Int,
        screenshotCount: Int,
        candidates: [PHAsset]
    ) {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]
        let fetched = PHAsset.fetchAssets(with: .image, options: options)
        var libraryImageCount = 0
        var screenshotCount = 0
        var candidates: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in
            libraryImageCount += 1
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                screenshotCount += 1
            } else {
                candidates.append(asset)
            }
        }
        return (libraryImageCount, screenshotCount, candidates)
    }

    /// 同步取图（禁网络）+ 一次特征计算。**同步请求阻塞本线程**，故只在本文件的并发队列上跑。
    static func measureOne(
        asset: PHAsset,
        manager: PHImageManager
    ) -> (
        measurement: SimilarPhotosFeatureMeasurement,
        observation: VNFeaturePrintObservation?
    ) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isSynchronous = true
        options.isNetworkAccessAllowed = false

        var image: UIImage?
        var info: [AnyHashable: Any]?
        let fetchStart = Date()
        manager.requestImage(
            for: asset,
            targetSize: CGSize(
                width: SimilarPhotosProbeLimits.targetSide,
                height: SimilarPhotosProbeLimits.targetSide
            ),
            contentMode: .aspectFit,
            options: options
        ) { result, resultInfo in
            image = result
            info = resultInfo
        }
        let fetchMilliseconds = Date().timeIntervalSince(fetchStart) * 1_000

        guard let cgImage = image?.cgImage else {
            let inCloud = (info?[PHImageResultIsInCloudKey] as? Bool) == true
            let measurement = SimilarPhotosFeatureMeasurement(
                fetchMilliseconds: fetchMilliseconds,
                visionMilliseconds: 0,
                outcome: inCloud ? .inCloud : .failed
            )
            return (measurement, nil)
        }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let visionStart = Date()
        do {
            try handler.perform([request])
        } catch {
            let measurement = SimilarPhotosFeatureMeasurement(
                fetchMilliseconds: fetchMilliseconds,
                visionMilliseconds: Date().timeIntervalSince(visionStart) * 1_000,
                outcome: .failed
            )
            return (measurement, nil)
        }
        let visionMilliseconds = Date().timeIntervalSince(visionStart) * 1_000
        let results: [Any] = request.results ?? []
        guard let observation = results.first as? VNFeaturePrintObservation else {
            let measurement = SimilarPhotosFeatureMeasurement(
                fetchMilliseconds: fetchMilliseconds,
                visionMilliseconds: visionMilliseconds,
                outcome: .failed
            )
            return (measurement, nil)
        }
        let measurement = SimilarPhotosFeatureMeasurement(
            fetchMilliseconds: fetchMilliseconds,
            visionMilliseconds: visionMilliseconds,
            outcome: .ok
        )
        return (measurement, observation)
    }
}
