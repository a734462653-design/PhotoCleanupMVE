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

// MARK: - 探针常量

/// 探针自己的上限常量。不是产品取值，不进 `S2CalibrationConfiguration`。
enum SimilarPhotosProbeLimits {
    /// 分块大小：块内并发算特征，块算完即释放，特征不常驻内存。
    static let chunkSize = 64
    /// 取图目标边长。
    static let targetSide: CGFloat = 360
    /// 面板并发度选择器的取值。
    static let concurrencyOptions = [1, 2, 4]
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
        sampleAssetIDs = []
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
                        collector.notePrint(
                            count: observation.elementCount,
                            typeRawValue: Int(observation.elementType.rawValue),
                            bytes: observation.data.count
                        )
                    }
                }
            }
            group.wait()
            processed = collector.finishedCount
            progress(processed, sample.count)
            // 每一块采一次可用内存，取最小值：特征随块释放，量到的才是提取的水位。
            collector.noteMemory(memorySample())
        }

        let wallClockSeconds = Date().timeIntervalSince(runStart)
        let snapshot = collector.snapshot
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
            cancelled: cancellation.isCancelled
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
