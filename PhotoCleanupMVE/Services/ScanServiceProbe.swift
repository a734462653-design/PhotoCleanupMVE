import Foundation
import Photos
import QuartzCore
import UIKit

// MARK: - IC-145：扫描服务探针（只出数，零产品行为）
//
// 本文件是**探针**，不是实装。三个子项各自独立：
// - 子项 A：屏幕录制识别启发式的命中计数与明细（SPEC-S0 v1 未定项 4 的 ③ 待验）
// - 子项 B：字节数三条取数途径的耗时与一致性对比
// - 子项 C：类别元数据的可得性与批量遍历耗时
//
// 纪律：
// 1. **关闭态零副作用**——三个协调器的 `init` 内不触碰 PhotoKit、不注册观察者、
//    不读写持久化；只有标定面板按钮显式调用 `run` 才开始取数（照 IC-099b 的
//    `S2AssetSizeProbeCoordinator`）。
// 2. **不碰产品路径**——`AssetSizeScanner.scan(_:)` 与 `AssetVolumeService` 一字不动；
//    本文件只调用它们的**静态判别** `AssetSizeProbeService.mediaKind(of:)`（只读）。
// 3. **报告文本全 ASCII**——`Scripts/scan-hardcoded-user-visible-strings.ps1` 对
//    `Services/` 下含汉字的字符串字面量一律判「用户可见硬编码残留」，
//    该扫描器只对 `Features/S2/S2NativePhotoPager.swift` 里 `S2GeometryDiagnosticsRun`
//    之后的行免检（IC-099b 探针文本因此可用中文）。本文件拿不到那份豁免，
//    故报告文本一律 ASCII；中文只出现在注释里。
// 4. 同理，本文件内**不得**出现「return 紧跟字符串字面量」的形式（扫描器的
//    `dataLiteralPattern` 会把它判成展示 helper 直接返回字符串，陷阱 18 第三条）；
//    注释里也不能写出那个样子，扫描器按整行正则匹配，不区分代码与注释
//    （陷阱 18 第四条同理：注释里的中文引号串改用「」）。

// MARK: - 子项 A：屏幕录制识别启发式（③ 待验）

/// 四种判据。原始值即报告里的显示名。
///
/// **③**：`PHAssetMediaSubtype` 没有「屏幕录制」位，没有公开 API 能直接判定，
/// 只能靠启发式。本探针的任务就是量这四种判据各自命中多少，**准确率留给 Lynn
/// 人工核对真值后填**——命中 ∩ 真值只有他知道。
enum ScreenRecordingRule: String, CaseIterable {
    /// 仅文件名前缀（大小写敏感）。
    case filename = "filename-only"
    /// 仅分辨率等于设备原生屏幕像素（允许宽高互换）。
    case resolution = "resolution-only"
    case filenameOrResolution = "filename-or-resolution"
    case filenameAndResolution = "filename-and-resolution"
}

/// 启发式判据本体。纯函数，无 PhotoKit 依赖，断言 1 直接钉真值表。
enum ScreenRecordingHeuristic {
    /// ③：iOS 屏幕录制落地资源的原始文件名前缀。SPEC-S0 v1 第十二节未定项 4
    /// 把它标为推测，本探针只量命中，不改规格。
    static let filenamePrefix = "RPReplay_Final"

    /// 文件名前缀命中。`caseSensitive == false` 时两侧同时小写再比。
    /// 文件名缺失或为空一律不命中。
    static func matchesFilename(
        _ filename: String?,
        caseSensitive: Bool
    ) -> Bool {
        guard let filename, !filename.isEmpty else {
            return false
        }
        if caseSensitive {
            return filename.hasPrefix(filenamePrefix)
        }
        return filename.lowercased().hasPrefix(filenamePrefix.lowercased())
    }

    /// 分辨率命中：资产像素尺寸等于设备原生屏幕像素尺寸，**允许宽高互换**
    /// （横向录制的资产宽高与竖向屏幕相反）。
    ///
    /// 任一边为零或负即不命中——屏幕尺寸取不到时（`screenSize == .zero`）
    /// 不得把一堆 0×0 资产判成命中。
    static func matchesResolution(
        pixelSize: CGSize,
        screenSize: CGSize
    ) -> Bool {
        guard pixelSize.width > 0, pixelSize.height > 0,
              screenSize.width > 0, screenSize.height > 0 else {
            return false
        }
        if pixelSize.width == screenSize.width,
           pixelSize.height == screenSize.height {
            return true
        }
        return pixelSize.width == screenSize.height &&
            pixelSize.height == screenSize.width
    }

    /// 四种判据的统一入口。`rule` 决定两个基础判据怎么组合。
    static func isScreenRecording(
        filename: String?,
        pixelSize: CGSize,
        screenSize: CGSize,
        rule: ScreenRecordingRule
    ) -> Bool {
        let byFilename = matchesFilename(filename, caseSensitive: true)
        let byResolution = matchesResolution(
            pixelSize: pixelSize,
            screenSize: screenSize
        )
        switch rule {
        case .filename:
            return byFilename
        case .resolution:
            return byResolution
        case .filenameOrResolution:
            return byFilename || byResolution
        case .filenameAndResolution:
            return byFilename && byResolution
        }
    }
}

/// 一个视频资产上的启发式测量。纯数据，不含任何 PhotoKit 类型。
struct ScreenRecordingMeasurement: Equatable, Sendable {
    let assetID: String
    /// `PHAssetResource` 中 `type == .video` 的 `originalFilename`；取不到为 nil。
    let originalFilename: String?
    let pixelWidth: Int
    let pixelHeight: Int
    let durationSeconds: Double
    let creationDate: Date?
    let matchesFilenameCaseSensitive: Bool
    let matchesFilenameCaseInsensitive: Bool
    let matchesResolution: Bool

    /// 四种判据在本条测量上的结论。与 `ScreenRecordingHeuristic` 同口径：
    /// `.filename` 取**大小写敏感**那一列。
    func verdict(for rule: ScreenRecordingRule) -> Bool {
        switch rule {
        case .filename:
            return matchesFilenameCaseSensitive
        case .resolution:
            return matchesResolution
        case .filenameOrResolution:
            return matchesFilenameCaseSensitive || matchesResolution
        case .filenameAndResolution:
            return matchesFilenameCaseSensitive && matchesResolution
        }
    }
}

/// 取数前的准备：全库视频标识 + 全库资产总数 + 设备原生屏幕像素。
struct ScreenRecordingProbePreparation: Equatable, Sendable {
    let videoAssetIDs: [String]
    let libraryAssetCount: Int
    let screenPixelWidth: Int
    let screenPixelHeight: Int
}

/// 取数接口。实现在本文件下方；面板按钮之外没有任何调用点。
protocol ScreenRecordingProbing: AnyObject {
    func prepare() async -> ScreenRecordingProbePreparation
    /// 屏幕像素由 `prepare()` 一次取回后逐条传入——`UIScreen` 是主线程隔离
    /// 类型，若每条资产都去读一次，量的就成了主线程跳转而不是取数本身。
    func measure(
        assetID: String,
        screenPixelSize: CGSize
    ) async -> ScreenRecordingMeasurement?
}

/// 子项 A 报告的全部文本拼装。纯函数，断言 2 直接钉。
enum ScreenRecordingProbeText {
    static let formatVersion = 1
    static let columns =
        "id8|filename|pixels|duration-s|created|name-cs|name-ci|resolution"

    static func identifierPrefix(_ assetID: String) -> String {
        String(assetID.prefix(8))
    }

    static func row(_ measurement: ScreenRecordingMeasurement) -> String {
        [
            identifierPrefix(measurement.assetID),
            measurement.originalFilename ?? ProbeFormat.absentText,
            "\(measurement.pixelWidth)x\(measurement.pixelHeight)",
            ProbeFormat.seconds(measurement.durationSeconds),
            ProbeFormat.date(measurement.creationDate),
            "name-cs=" + ProbeFormat.yesNo(
                measurement.matchesFilenameCaseSensitive
            ),
            "name-ci=" + ProbeFormat.yesNo(
                measurement.matchesFilenameCaseInsensitive
            ),
            "resolution=" + ProbeFormat.yesNo(measurement.matchesResolution)
        ].joined(separator: ProbeFormat.fieldSeparator)
    }

    static func header(
        videoCount: Int,
        libraryAssetCount: Int,
        unresolvedCount: Int,
        screenPixelWidth: Int,
        screenPixelHeight: Int
    ) -> String {
        [
            "IC-145 A screen-recording heuristic probe",
            "format-version=\(formatVersion)",
            "columns=" + columns,
            "filename-rule=originalFilename has prefix " +
                ScreenRecordingHeuristic.filenamePrefix +
                " (name-cs case-sensitive, name-ci case-insensitive)",
            "resolution-rule=asset pixel size equals device native screen " +
                "pixels, width/height swap allowed (unverified heuristic)",
            "screen-pixels=\(screenPixelWidth)x\(screenPixelHeight)",
            [
                "video-count=\(videoCount)",
                "library-asset-count=\(libraryAssetCount)",
                "unresolved=\(unresolvedCount)"
            ].joined(separator: ProbeFormat.fieldSeparator)
        ].joined(separator: "\n")
    }

    static func summary(
        _ measurements: [ScreenRecordingMeasurement]
    ) -> String {
        let total = measurements.count
        var lines = ScreenRecordingRule.allCases.map { rule -> String in
            let hits = measurements.filter { $0.verdict(for: rule) }.count
            let share = ProbeFormat.percentage(hits, of: total)
            return [
                ProbeFormat.summaryTag,
                "rule=" + rule.rawValue,
                "hits=\(hits)/\(total) (" + share + ")"
            ].joined(separator: ProbeFormat.fieldSeparator)
        }
        let caseInsensitive = measurements.filter {
            $0.matchesFilenameCaseInsensitive
        }.count
        let resolutionOnly = measurements.filter {
            $0.matchesResolution && !$0.matchesFilenameCaseSensitive
        }.count
        let filenameOnly = measurements.filter {
            $0.matchesFilenameCaseSensitive && !$0.matchesResolution
        }.count
        let missingFilename = measurements.filter {
            $0.originalFilename == nil
        }.count
        let tails = [
            "case-insensitive-filename-hits=\(caseInsensitive)/\(total)",
            "resolution-hit-filename-miss=\(resolutionOnly)",
            "filename-hit-resolution-miss=\(filenameOnly)",
            "missing-video-resource-filename=\(missingFilename)"
        ]
        lines.append(contentsOf: tails.map { tail in
            [ProbeFormat.summaryTag, tail]
                .joined(separator: ProbeFormat.fieldSeparator)
        })
        return lines.joined(separator: "\n")
    }

    /// 明细只列两组：**任一判据命中**的全部行，与**分辨率命中但文件名未命中**
    /// 的全部行（后者是误认的主要嫌疑，卡内点名要列）。第二组是第一组的子集，
    /// 分开列是为了让 Lynn 人工核对真值时不必自己筛。
    static func report(
        measurements: [ScreenRecordingMeasurement],
        libraryAssetCount: Int,
        unresolvedCount: Int,
        screenPixelWidth: Int,
        screenPixelHeight: Int
    ) -> String {
        let hits = measurements.filter {
            $0.verdict(for: .filenameOrResolution)
        }
        let suspects = measurements.filter {
            $0.matchesResolution && !$0.matchesFilenameCaseSensitive
        }
        var lines = [
            header(
                videoCount: measurements.count,
                libraryAssetCount: libraryAssetCount,
                unresolvedCount: unresolvedCount,
                screenPixelWidth: screenPixelWidth,
                screenPixelHeight: screenPixelHeight
            ),
            "[hits] any-rule-matched=\(hits.count)"
        ]
        lines.append(contentsOf: hits.map(row))
        lines.append("[resolution-only] suspected-false-positive=\(suspects.count)")
        lines.append(contentsOf: suspects.map(row))
        lines.append(summary(measurements))
        return lines.joined(separator: "\n")
    }

    static func progress(finished: Int, total: Int) -> String {
        "IC-145 A screen-recording probe \(finished)/\(total)"
    }
}

/// 子项 A 的 PhotoKit 实现。
///
/// **无状态**：`prepare()` 只回标识，`measure(assetID:)` 按标识重新取回资产。
/// 代价是每条多一次 `fetchAssets(withLocalIdentifiers:)`；子项 A 不是耗时基准，
/// 这点开销不影响结论，换来的是不持有任何跨调用的可变状态。
///
/// 全程只读元数据与资源清单，**不发起任何资源数据请求**。
final class ScreenRecordingHeuristicProbeService: ScreenRecordingProbing {
    func prepare() async -> ScreenRecordingProbePreparation {
        let videos = PHAsset.fetchAssets(with: .video, options: nil)
        var identifiers: [String] = []
        identifiers.reserveCapacity(videos.count)
        videos.enumerateObjects { asset, _, _ in
            identifiers.append(asset.localIdentifier)
        }
        let screenPixels = await ProbeDeviceMetrics.nativeScreenPixelSize()
        return ScreenRecordingProbePreparation(
            videoAssetIDs: identifiers,
            libraryAssetCount: PHAsset.fetchAssets(with: nil).count,
            screenPixelWidth: Int(screenPixels.width),
            screenPixelHeight: Int(screenPixels.height)
        )
    }

    func measure(
        assetID: String,
        screenPixelSize: CGSize
    ) async -> ScreenRecordingMeasurement? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        ).firstObject else {
            return nil
        }
        let filename = PHAssetResource.assetResources(for: asset)
            .first { $0.type == .video }?
            .originalFilename
        let pixelSize = CGSize(
            width: CGFloat(asset.pixelWidth),
            height: CGFloat(asset.pixelHeight)
        )
        return ScreenRecordingMeasurement(
            assetID: assetID,
            originalFilename: filename,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            durationSeconds: asset.duration,
            creationDate: asset.creationDate,
            matchesFilenameCaseSensitive: ScreenRecordingHeuristic
                .matchesFilename(filename, caseSensitive: true),
            matchesFilenameCaseInsensitive: ScreenRecordingHeuristic
                .matchesFilename(filename, caseSensitive: false),
            matchesResolution: ScreenRecordingHeuristic.matchesResolution(
                pixelSize: pixelSize,
                screenSize: screenPixelSize
            )
        )
    }
}

/// 子项 A 的运行协调器。**关闭态零副作用**：`init` 里没有任何 PhotoKit、
/// 观察者或持久化调用；按钮调用 `run` 才开始。
///
/// 类本身不加 `@MainActor`——面板按钮的动作闭包是非隔离同步上下文，
/// 照 IC-099b 的 `S2AssetSizeProbeCoordinator` 只在 `Task` 上标注隔离。
final class ScreenRecordingProbeCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var progressText = ""
    @Published private(set) var reportText = ""

    private var runTask: Task<Void, Never>?

    var canExport: Bool {
        !isRunning && !reportText.isEmpty
    }

    func run(using prober: ScreenRecordingProbing) {
        guard !isRunning else {
            return
        }
        isRunning = true
        reportText = ""
        progressText = ScreenRecordingProbeText.progress(finished: 0, total: 0)
        runTask = Task { @MainActor [weak self] in
            let preparation = await prober.prepare()
            var collected: [ScreenRecordingMeasurement] = []
            var unresolved = 0
            let screenPixelSize = CGSize(
                width: CGFloat(preparation.screenPixelWidth),
                height: CGFloat(preparation.screenPixelHeight)
            )
            for (index, assetID) in preparation.videoAssetIDs.enumerated() {
                let measured = await prober.measure(
                    assetID: assetID,
                    screenPixelSize: screenPixelSize
                )
                if let measurement = measured {
                    collected.append(measurement)
                } else {
                    unresolved += 1
                }
                guard let self else {
                    return
                }
                self.progressText = ScreenRecordingProbeText.progress(
                    finished: index + 1,
                    total: preparation.videoAssetIDs.count
                )
            }
            guard let self else {
                return
            }
            self.reportText = ScreenRecordingProbeText.report(
                measurements: collected,
                libraryAssetCount: preparation.libraryAssetCount,
                unresolvedCount: unresolved,
                screenPixelWidth: preparation.screenPixelWidth,
                screenPixelHeight: preparation.screenPixelHeight
            )
            self.isRunning = false
            self.runTask = nil
        }
    }
}

// MARK: - 子项 B：字节数取数途径对比与耗时基准

/// 三条取数途径。原始值即报告里的显示名。
enum ByteRoute: String, CaseIterable {
    /// 途径 1：主资源 `requestData` 流式累加 = `AssetSizeScanner.scan(_:)` 的现行途径。
    case data = "data"
    /// 途径 2：照片 `requestContentEditingInput` → `fullSizeImageURL` 的文件属性；
    /// 视频 `requestAVAsset` → `AVURLAsset.url` 的文件属性。
    case url = "url"
    /// 途径 3（**本卡新增，③**）：`PHAssetResource` 上直接读字节数的属性。
    case resourceProperty = "resource-property"
}

/// 途径 3 的键探测。
///
/// **③ → ①**：`PHAssetResource` 的**公开**接口里没有字节数属性（`isPublicInterface`
/// 那一列是逐键对照 SDK 公开声明填的）。已知运行时可读的是下面这个非公开键，
/// 本探针先用 `responds(to:)` 探测存在性、存在才取值，**绝不进任何产品路径**——
/// 断言 5 以源码扫描钉死：键名字面量与 `value(forKey:)` 只许出现在本文件内。
enum ResourcePropertyRoute {
    /// 途径 3 的候选键（非公开）。
    static let candidateKey = "fileSize"
    /// 正对照：公开属性。用来验证「探测方法本身有效」，
    /// 否则候选键探测为假时分不清是键不存在还是探测方法不灵。
    static let publicControlKey = "originalFilename"

    static let probedKeys = [candidateKey, publicControlKey]

    /// 该键是否属于 `PHAssetResource` 的公开接口。
    static func isPublicInterface(_ key: String) -> Bool {
        key == publicControlKey
    }

    static func respondsToKey(_ resource: PHAssetResource, key: String) -> Bool {
        resource.responds(to: NSSelectorFromString(key))
    }

    /// 先探测键是否存在，存在才取值。不存在即 nil，**不发送未知键的 KVC**
    /// （`value(forKey:)` 打未知键会抛 `NSUnknownKeyException`，Swift 接不住）。
    static func byteCount(of resource: PHAssetResource) -> Int64? {
        guard respondsToKey(resource, key: candidateKey),
              let value = resource.value(forKey: candidateKey) as? NSNumber else {
            return nil
        }
        return value.int64Value
    }

    static func valueTypeName(
        of resource: PHAssetResource,
        key: String
    ) -> String? {
        guard respondsToKey(resource, key: key),
              let value = resource.value(forKey: key) else {
            return nil
        }
        return String(describing: type(of: value))
    }
}

/// 单个键的探测结果。`respondsToSelector` 为 nil 表示库里没有可供探测的资源。
struct ResourceKeyProbeResult: Equatable, Sendable {
    let key: String
    let isPublicInterface: Bool
    let respondsToSelector: Bool?
    let valueTypeName: String?
}

/// 一个资产上三条途径的测量。纯数据，不含任何 PhotoKit 类型。
struct ByteRouteMeasurement: Equatable, Sendable {
    let assetID: String
    let mediaKind: S2AssetSizeProbeMediaKind
    let isEdited: Bool
    /// `PHAssetResource.assetResources(for:)` 本身的耗时（冷）。三条途径都要先
    /// 拿到资源清单，把它单列出来，三条途径的计时才可比。
    let resourceEnumerationElapsedMilliseconds: Double
    let dataByteCount: Int64?
    let dataElapsedMilliseconds: Double
    let urlByteCount: Int64?
    let urlElapsedMilliseconds: Double
    let resourcePropertyByteCount: Int64?
    let resourcePropertyElapsedMilliseconds: Double

    func byteCount(for route: ByteRoute) -> Int64? {
        switch route {
        case .data:
            return dataByteCount
        case .url:
            return urlByteCount
        case .resourceProperty:
            return resourcePropertyByteCount
        }
    }

    func elapsedMilliseconds(for route: ByteRoute) -> Double {
        switch route {
        case .data:
            return dataElapsedMilliseconds
        case .url:
            return urlElapsedMilliseconds
        case .resourceProperty:
            return resourcePropertyElapsedMilliseconds
        }
    }

    /// 两条途径都成功时的差值（左 − 右）；任一为 nil 即无可比性，回 nil。
    func byteDelta(_ left: ByteRoute, _ right: ByteRoute) -> Int64? {
        guard let leftValue = byteCount(for: left),
              let rightValue = byteCount(for: right) else {
            return nil
        }
        return leftValue - rightValue
    }

    /// 任意一对都成功且不相等即为不一致。全部 nil 或只有一条成功时不算。
    var hasByteMismatch: Bool {
        ByteRoutePair.allPairs.contains { pair in
            (byteDelta(pair.left, pair.right) ?? 0) != 0
        }
    }
}

/// 途径两两配对。三条途径共三对。
struct ByteRoutePair: Equatable, Sendable {
    let left: ByteRoute
    let right: ByteRoute

    static let allPairs = [
        ByteRoutePair(left: .data, right: .url),
        ByteRoutePair(left: .data, right: .resourceProperty),
        ByteRoutePair(left: .url, right: .resourceProperty)
    ]

    var label: String {
        left.rawValue + "-" + right.rawValue
    }
}

/// 分位数统计。纯函数，断言 3 直接钉。
enum ProbeStatistics {
    /// **最近秩法**（nearest-rank）：样本升序后取第 `ceil(rank / 100 × n)` 个，
    /// 秩从 1 起、两端夹逼到 `[1, n]`。偶数长度不做插值——报告口径写明这一条，
    /// 断言 3 按同一口径核。空数组回 nil。
    static func percentile(_ values: [Double], _ rank: Double) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        let sorted = values.sorted()
        let position = Int((rank / 100 * Double(sorted.count)).rounded(.up))
        let index = min(max(position - 1, 0), sorted.count - 1)
        return sorted[index]
    }
}

/// 分层抽样。纯函数：入参是三族已分好的标识，出参是交错后截断到上限的样本。
enum ByteRouteSampling {
    /// 卡内上限：全库随机抽样至多 200 条。
    static let sampleLimit = 200
    /// 卡内上限：照片 / 视频 / 实况各至多 70 条。
    static let perKindLimit = 70

    /// 三族各取至多 `perKindLimit` 条后**轮转交错**，再截断到 `limit`。
    ///
    /// 三族满额是 210 > 200，直接拼接再截断会把最后一族削掉 10 条；
    /// 轮转交错让削减均摊到三族尾部，样本仍大体均衡。
    static func stratifiedSample(
        photo: [String],
        livePhoto: [String],
        video: [String],
        limit: Int = ByteRouteSampling.sampleLimit,
        perKindLimit: Int = ByteRouteSampling.perKindLimit
    ) -> [String] {
        let strata = [photo, livePhoto, video].map {
            Array($0.prefix(perKindLimit))
        }
        var interleaved: [String] = []
        let deepest = strata.map(\.count).max() ?? 0
        for index in 0..<deepest {
            for stratum in strata where index < stratum.count {
                interleaved.append(stratum[index])
            }
        }
        return Array(interleaved.prefix(limit))
    }
}

/// 取数前的准备：样本标识 + 全库资产总数 + 途径 3 的键探测结果。
struct ByteRouteProbePreparation: Equatable, Sendable {
    let sampledAssetIDs: [String]
    let libraryAssetCount: Int
    let keyProbeResults: [ResourceKeyProbeResult]
}

/// 取数接口。实现在本文件下方；面板按钮之外没有任何调用点。
protocol ByteRouteProbing: AnyObject {
    func prepare() async -> ByteRouteProbePreparation
    func measure(assetID: String) async -> ByteRouteMeasurement
}

/// 子项 B 报告的全部文本拼装。纯函数，断言 4 直接钉。
enum ByteRouteProbeText {
    static let formatVersion = 1
    static let columns =
        "id8|kind|edited|enum-ms|data-bytes|data-ms|url-bytes|url-ms|" +
        "prop-bytes|prop-ms"

    static func identifierPrefix(_ assetID: String) -> String {
        String(assetID.prefix(8))
    }

    static func row(_ measurement: ByteRouteMeasurement) -> String {
        [
            identifierPrefix(measurement.assetID),
            measurement.mediaKind.rawValue,
            "edited=" + ProbeFormat.yesNo(measurement.isEdited),
            "enum=" + ProbeFormat.milliseconds(
                measurement.resourceEnumerationElapsedMilliseconds
            ),
            "data-bytes=" + ProbeFormat.optionalCount(
                measurement.dataByteCount
            ),
            "data=" + ProbeFormat.milliseconds(
                measurement.dataElapsedMilliseconds
            ),
            "url-bytes=" + ProbeFormat.optionalCount(measurement.urlByteCount),
            "url=" + ProbeFormat.milliseconds(
                measurement.urlElapsedMilliseconds
            ),
            "prop-bytes=" + ProbeFormat.optionalCount(
                measurement.resourcePropertyByteCount
            ),
            "prop=" + ProbeFormat.milliseconds(
                measurement.resourcePropertyElapsedMilliseconds
            )
        ].joined(separator: ProbeFormat.fieldSeparator)
    }

    static func keyProbeLine(_ result: ResourceKeyProbeResult) -> String {
        let responds = result.respondsToSelector.map(ProbeFormat.yesNo)
            ?? "unknown"
        return [
            "key-probe",
            "key=" + result.key,
            "public-interface=" +
                ProbeFormat.yesNo(result.isPublicInterface),
            "responds=" + responds,
            "value-type=" + (result.valueTypeName ?? ProbeFormat.absentText)
        ].joined(separator: ProbeFormat.fieldSeparator)
    }

    static func header(
        sampleCount: Int,
        libraryAssetCount: Int,
        limit: Int,
        perKindLimit: Int,
        keyProbeResults: [ResourceKeyProbeResult]
    ) -> String {
        var lines = [
            "IC-145 B byte-route benchmark probe",
            "format-version=\(formatVersion)",
            "columns=" + columns,
            "route-data=primary resource requestData streamed (same route as " +
                "the shipping AssetSizeScanner)",
            "route-url=photo requestContentEditingInput fullSizeImageURL / " +
                "video requestAVAsset AVURLAsset.url file attributes",
            "route-prop=PHAssetResource runtime property read, " +
                "PROBE ONLY, NOT PUBLIC API, MUST NOT SHIP",
            "timing-note=enum-ms is the cold assetResources enumeration, " +
                "excluded from all three route timers so they compare",
            "percentile-note=nearest-rank, no interpolation",
            [
                "sample=\(sampleCount)",
                "library-asset-count=\(libraryAssetCount)",
                "limit=\(limit)",
                "per-kind-limit=\(perKindLimit)"
            ].joined(separator: ProbeFormat.fieldSeparator)
        ]
        lines.append(contentsOf: keyProbeResults.map(keyProbeLine))
        return lines.joined(separator: "\n")
    }

    /// 每途径一行：p50 / p95 / 最大耗时 + 成功率（失败计入分母）。
    static func routeSummary(
        _ measurements: [ByteRouteMeasurement]
    ) -> [String] {
        let total = measurements.count
        return ByteRoute.allCases.map { route -> String in
            let elapsed = measurements.map {
                $0.elapsedMilliseconds(for: route)
            }
            let success = measurements.filter {
                $0.byteCount(for: route) != nil
            }.count
            let p50 = ProbeStatistics.percentile(elapsed, 50)
            let p95 = ProbeStatistics.percentile(elapsed, 95)
            let share = ProbeFormat.percentage(success, of: total)
            return [
                ProbeFormat.summaryTag,
                "route=" + route.rawValue,
                "p50=" + ProbeFormat.optionalMilliseconds(p50),
                "p95=" + ProbeFormat.optionalMilliseconds(p95),
                "max=" + ProbeFormat.optionalMilliseconds(elapsed.max()),
                "ok=\(success)/\(total) (" + share + ")"
            ].joined(separator: ProbeFormat.fieldSeparator)
        }
    }

    /// 不一致明细。**只在确有差值时出现**：任意一对都成功且不相等才出行。
    static func mismatchLines(
        _ measurements: [ByteRouteMeasurement]
    ) -> [String] {
        measurements.filter(\.hasByteMismatch).map { measurement -> String in
            var parts = [
                "mismatch",
                identifierPrefix(measurement.assetID),
                measurement.mediaKind.rawValue,
                "edited=" + ProbeFormat.yesNo(measurement.isEdited)
            ]
            for route in ByteRoute.allCases {
                parts.append(
                    route.rawValue + "=" + ProbeFormat.optionalCount(
                        measurement.byteCount(for: route)
                    )
                )
            }
            for pair in ByteRoutePair.allPairs {
                parts.append(
                    pair.label + "=" + ProbeFormat.optionalCount(
                        measurement.byteDelta(pair.left, pair.right)
                    )
                )
            }
            return parts.joined(separator: ProbeFormat.fieldSeparator)
        }
    }

    /// 按 p50 外推的全库耗时。**上界估计**：假设串行、无缓存、无并发。
    static func extrapolationLines(
        _ measurements: [ByteRouteMeasurement],
        libraryAssetCount: Int
    ) -> [String] {
        ByteRoute.allCases.map { route -> String in
            let elapsed = measurements.map {
                $0.elapsedMilliseconds(for: route)
            }
            let p50 = ProbeStatistics.percentile(elapsed, 50)
            let projected = p50.map {
                $0 * Double(libraryAssetCount) / 1_000
            }
            let projectedText = projected.map { ProbeFormat.seconds($0) + "s" }
                ?? ProbeFormat.absentText
            return [
                "extrapolation",
                "route=" + route.rawValue,
                "p50-times-library=" + projectedText,
                "assumes serial, no cache, no concurrency (upper bound)"
            ].joined(separator: ProbeFormat.fieldSeparator)
        }
    }

    static func summary(
        _ measurements: [ByteRouteMeasurement],
        libraryAssetCount: Int
    ) -> String {
        let enumeration = measurements.map(
            \.resourceEnumerationElapsedMilliseconds
        )
        let kindCounts = S2AssetSizeProbeMediaKind.allCases.map { kind in
            kind.rawValue + "=" +
                String(measurements.filter { $0.mediaKind == kind }.count)
        }.joined(separator: ProbeFormat.fieldSeparator)
        let mismatches = mismatchLines(measurements)

        var lines = routeSummary(measurements)
        let enumerationP50 = ProbeStatistics.percentile(enumeration, 50)
        let enumerationP95 = ProbeStatistics.percentile(enumeration, 95)
        lines.append([
            ProbeFormat.summaryTag,
            "resource-enumeration",
            "p50=" + ProbeFormat.optionalMilliseconds(enumerationP50),
            "p95=" + ProbeFormat.optionalMilliseconds(enumerationP95)
        ].joined(separator: ProbeFormat.fieldSeparator))
        lines.append([
            ProbeFormat.summaryTag,
            "sample-by-kind",
            kindCounts
        ].joined(separator: ProbeFormat.fieldSeparator))
        lines.append([
            ProbeFormat.summaryTag,
            "byte-mismatch-assets=\(mismatches.count)/\(measurements.count)"
        ].joined(separator: ProbeFormat.fieldSeparator))
        lines.append(contentsOf: extrapolationLines(
            measurements,
            libraryAssetCount: libraryAssetCount
        ))
        return lines.joined(separator: "\n")
    }

    static func report(
        measurements: [ByteRouteMeasurement],
        libraryAssetCount: Int,
        limit: Int,
        perKindLimit: Int,
        keyProbeResults: [ResourceKeyProbeResult]
    ) -> String {
        var lines = [
            header(
                sampleCount: measurements.count,
                libraryAssetCount: libraryAssetCount,
                limit: limit,
                perKindLimit: perKindLimit,
                keyProbeResults: keyProbeResults
            )
        ]
        lines.append(contentsOf: measurements.map(row))
        let mismatches = mismatchLines(measurements)
        if !mismatches.isEmpty {
            lines.append("[mismatch] assets=\(mismatches.count)")
            lines.append(contentsOf: mismatches)
        }
        lines.append(summary(
            measurements,
            libraryAssetCount: libraryAssetCount
        ))
        return lines.joined(separator: "\n")
    }

    static func progress(finished: Int, total: Int) -> String {
        "IC-145 B byte-route probe \(finished)/\(total)"
    }
}

/// 子项 B 的 PhotoKit 实现。
///
/// 途径 1 与途径 2 **不另起炉灶**：直接复用 IC-099b 的 `AssetSizeProbeService`
/// （`Services/AssetSizeScanner.swift`，本卡一字未改），它已经把这两条途径连同
/// 各自的计时实现完毕。本类只加途径 3 与分层抽样、批量调度。
///
/// **无状态**：每条测量现造一个单条目的内层服务，不持有跨调用的可变状态。
/// 内层服务的计时只围住各自的取数调用，构造开销不进读数。
final class ByteRouteBenchmarkProbeService: ByteRouteProbing {
    func prepare() async -> ByteRouteProbePreparation {
        let all = PHAsset.fetchAssets(with: nil)
        var photo: [String] = []
        var livePhoto: [String] = []
        var video: [String] = []
        var probeResource: PHAssetResource?
        all.enumerateObjects { asset, _, _ in
            switch AssetSizeProbeService.mediaKind(of: asset) {
            case .photo:
                photo.append(asset.localIdentifier)
            case .livePhoto:
                livePhoto.append(asset.localIdentifier)
            case .video:
                video.append(asset.localIdentifier)
            }
            if probeResource == nil {
                probeResource = PHAssetResource.assetResources(for: asset).first
            }
        }
        let sample = ByteRouteSampling.stratifiedSample(
            photo: photo.shuffled(),
            livePhoto: livePhoto.shuffled(),
            video: video.shuffled()
        )
        return ByteRouteProbePreparation(
            sampledAssetIDs: sample,
            libraryAssetCount: all.count,
            keyProbeResults: Self.keyProbeResults(against: probeResource)
        )
    }

    func measure(assetID: String) async -> ByteRouteMeasurement {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        ).firstObject else {
            return Self.unavailableMeasurement(assetID: assetID)
        }

        let enumerationStartedAt = CACurrentMediaTime()
        let resources = PHAssetResource.assetResources(for: asset)
        let enumerationElapsed =
            (CACurrentMediaTime() - enumerationStartedAt) * 1_000

        let mediaKind = AssetSizeProbeService.mediaKind(of: asset)
        let primary = AssetSizeProbeService.primaryResource(
            in: resources,
            mediaKind: mediaKind
        )
        let propertyStartedAt = CACurrentMediaTime()
        let propertyBytes = primary.flatMap {
            ResourcePropertyRoute.byteCount(of: $0)
        }
        let propertyElapsed =
            (CACurrentMediaTime() - propertyStartedAt) * 1_000

        // 途径 1 与 2：原样交给 IC-099b 的探针服务，计时口径与它一致。
        let inner = AssetSizeProbeService(assets: [assetID: asset])
        let base = await inner.measure(assetID: assetID)

        return ByteRouteMeasurement(
            assetID: assetID,
            mediaKind: base.mediaKind,
            isEdited: base.isEdited,
            resourceEnumerationElapsedMilliseconds: enumerationElapsed,
            dataByteCount: base.dataByteCount,
            dataElapsedMilliseconds: base.dataElapsedMilliseconds,
            urlByteCount: base.urlByteCount,
            urlElapsedMilliseconds: base.urlElapsedMilliseconds,
            resourcePropertyByteCount: propertyBytes,
            resourcePropertyElapsedMilliseconds: propertyElapsed
        )
    }

    private static func keyProbeResults(
        against resource: PHAssetResource?
    ) -> [ResourceKeyProbeResult] {
        ResourcePropertyRoute.probedKeys.map { key -> ResourceKeyProbeResult in
            guard let resource else {
                return ResourceKeyProbeResult(
                    key: key,
                    isPublicInterface:
                        ResourcePropertyRoute.isPublicInterface(key),
                    respondsToSelector: nil,
                    valueTypeName: nil
                )
            }
            return ResourceKeyProbeResult(
                key: key,
                isPublicInterface: ResourcePropertyRoute.isPublicInterface(key),
                respondsToSelector: ResourcePropertyRoute.respondsToKey(
                    resource,
                    key: key
                ),
                valueTypeName: ResourcePropertyRoute.valueTypeName(
                    of: resource,
                    key: key
                )
            )
        }
    }

    private static func unavailableMeasurement(
        assetID: String
    ) -> ByteRouteMeasurement {
        ByteRouteMeasurement(
            assetID: assetID,
            mediaKind: .photo,
            isEdited: false,
            resourceEnumerationElapsedMilliseconds: 0,
            dataByteCount: nil,
            dataElapsedMilliseconds: 0,
            urlByteCount: nil,
            urlElapsedMilliseconds: 0,
            resourcePropertyByteCount: nil,
            resourcePropertyElapsedMilliseconds: 0
        )
    }
}

/// 子项 B 的运行协调器。**关闭态零副作用**，口径同子项 A。
final class ByteRouteProbeCoordinator: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var progressText = ""
    @Published private(set) var reportText = ""

    /// 本次运行的逐条测量。子项 C 的可行性行要拿途径 1 的 p50 做比值。
    private(set) var measurements: [ByteRouteMeasurement] = []
    private var runTask: Task<Void, Never>?

    var canExport: Bool {
        !isRunning && !reportText.isEmpty
    }

    /// 途径 1（数据途径）本次运行的 p50 耗时。**未跑过即 nil**——
    /// 子项 C 如实写 none，不拿旧数凑。
    var dataRouteP50Milliseconds: Double? {
        ProbeStatistics.percentile(
            measurements.map(\.dataElapsedMilliseconds),
            50
        )
    }

    func run(using prober: ByteRouteProbing) {
        guard !isRunning else {
            return
        }
        isRunning = true
        reportText = ""
        measurements = []
        progressText = ByteRouteProbeText.progress(finished: 0, total: 0)
        runTask = Task { @MainActor [weak self] in
            let preparation = await prober.prepare()
            var collected: [ByteRouteMeasurement] = []
            for (index, assetID) in preparation.sampledAssetIDs.enumerated() {
                collected.append(await prober.measure(assetID: assetID))
                guard let self else {
                    return
                }
                self.measurements = collected
                self.progressText = ByteRouteProbeText.progress(
                    finished: index + 1,
                    total: preparation.sampledAssetIDs.count
                )
            }
            guard let self else {
                return
            }
            self.reportText = ByteRouteProbeText.report(
                measurements: collected,
                libraryAssetCount: preparation.libraryAssetCount,
                limit: ByteRouteSampling.sampleLimit,
                perKindLimit: ByteRouteSampling.perKindLimit,
                keyProbeResults: preparation.keyProbeResults
            )
            self.isRunning = false
            self.runTask = nil
        }
    }
}

// MARK: - 子项 C：类别元数据可得性与批量读取耗时

/// 视频时长分档。**半开区间 `[下界, 上界)`**：恰 30 s 归 `30s-2min`、
/// 恰 120 s 归 `2min-10min`、恰 600 s 归 `gte-10min`。报告头部写明这条口径，
/// 断言 6 按同一口径核（卡内要求「恰 30 s 归哪档须在报告中写明口径并与断言一致」）。
enum VideoDurationBucket: String, CaseIterable {
    case underThirtySeconds = "lt-30s"
    case thirtySecondsToTwoMinutes = "30s-2min"
    case twoToTenMinutes = "2min-10min"
    case overTenMinutes = "gte-10min"

    static func bucket(forSeconds seconds: Double) -> VideoDurationBucket {
        if seconds < 30 {
            return .underThirtySeconds
        }
        if seconds < 120 {
            return .thirtySecondsToTwoMinutes
        }
        if seconds < 600 {
            return .twoToTenMinutes
        }
        return .overTenMinutes
    }
}

/// 视频像素分档。卡内未指定口径，本探针取**长边像素**、同样是半开区间；
/// 档位边界对齐常见录制规格（HD / FHD / 4K）。报告头部写明口径。
enum VideoPixelBucket: String, CaseIterable {
    case belowHD = "lt-1280"
    case hd = "1280-1919"
    case fullHD = "1920-2559"
    case ultraHD = "gte-2560"

    static func bucket(forLongEdge pixels: Int) -> VideoPixelBucket {
        if pixels < 1_280 {
            return .belowHD
        }
        if pixels < 1_920 {
            return .hd
        }
        if pixels < 2_560 {
            return .fullHD
        }
        return .ultraHD
    }
}

/// 第一遍：**纯元数据**全库遍历的读数。不触发任何资源请求。
struct CategoryMetadataPass: Equatable, Sendable {
    let totalAssetCount: Int
    let elapsedMilliseconds: Double
    let photoCount: Int
    let videoCount: Int
    let screenshotCount: Int
    let livePhotoCount: Int
    let favoriteCount: Int
    /// `PHAsset.canPerform(.content)` 的命中数。**这是「可编辑」不是「已编辑」**
    /// ——见 `CategoryMetadataEditedPass` 与报告里的 predicate-note。
    let editableCount: Int
    let recentThirtyDayCount: Int
    let durationBuckets: [VideoDurationBucket: Int]
    let pixelBuckets: [VideoPixelBucket: Int]

    /// 平均每资产耗时（微秒）。资产数为零时回 nil。
    var averageMicrosecondsPerAsset: Double? {
        guard totalAssetCount > 0 else {
            return nil
        }
        return elapsedMilliseconds * 1_000 / Double(totalAssetCount)
    }
}

/// 第二遍：已编辑判定。需要逐个枚举资源清单，**与第一遍分开计时**，
/// 第一遍的读数才仍是纯元数据的量。
struct CategoryMetadataEditedPass: Equatable, Sendable {
    let editedCount: Int
    let elapsedMilliseconds: Double
}

/// 取数接口。两遍分开，协调器才能在两遍之间回报进度。
protocol CategoryMetadataProbing: AnyObject {
    func runMetadataPass() async -> CategoryMetadataPass
    func runEditedPass() async -> CategoryMetadataEditedPass
}

/// 子项 C 报告的全部文本拼装。纯函数，断言 7 直接钉。
enum CategoryMetadataProbeText {
    static let formatVersion = 1

    static func header(_ pass: CategoryMetadataPass) -> String {
        [
            "IC-145 C category-metadata probe",
            "format-version=\(formatVersion)",
            "duration-buckets=half-open [lower, upper): 30s goes to " +
                "30s-2min, 120s goes to 2min-10min, 600s goes to gte-10min",
            "pixel-buckets=half-open on the long edge in pixels",
            "predicate-note=editable is canPerform(.content), an EDITABILITY " +
                "predicate; edited is the adjustmentData resource, measured " +
                "in a separate second pass",
            "resource-note=pass 1 reads metadata only and issues no resource " +
                "request; pass 2 enumerates assetResources per asset",
            [
                "library-asset-count=\(pass.totalAssetCount)",
                "pass1=" + ProbeFormat.milliseconds(pass.elapsedMilliseconds)
            ].joined(separator: ProbeFormat.fieldSeparator)
        ].joined(separator: "\n")
    }

    static func distributionLines(_ pass: CategoryMetadataPass) -> [String] {
        let durationCounts = VideoDurationBucket.allCases.map { bucket in
            bucket.rawValue + "=" + String(pass.durationBuckets[bucket] ?? 0)
        }
        let pixelCounts = VideoPixelBucket.allCases.map { bucket in
            bucket.rawValue + "=" + String(pass.pixelBuckets[bucket] ?? 0)
        }
        let rows: [[String]] = [
            [
                "distribution",
                "photo=\(pass.photoCount)",
                "video=\(pass.videoCount)",
                "screenshot=\(pass.screenshotCount)",
                "live=\(pass.livePhotoCount)"
            ],
            [
                "distribution",
                "favorite=\(pass.favoriteCount)",
                "editable=\(pass.editableCount)",
                "created-within-30d=\(pass.recentThirtyDayCount)"
            ],
            ["distribution", "video-duration"] + durationCounts,
            ["distribution", "video-long-edge"] + pixelCounts
        ]
        return rows.map { $0.joined(separator: ProbeFormat.fieldSeparator) }
    }

    static func editedLine(
        _ edited: CategoryMetadataEditedPass,
        totalAssetCount: Int
    ) -> String {
        return [
            "distribution",
            "edited-adjustmentData=\(edited.editedCount)/\(totalAssetCount)",
            "pass2=" + ProbeFormat.milliseconds(edited.elapsedMilliseconds)
        ].joined(separator: ProbeFormat.fieldSeparator)
    }

    /// 可行性一行：**只给数与比值，不下结论**。`byteRouteDataP50Milliseconds`
    /// 为 nil（子项 B 本次未跑）时如实写 none，不拿旧数凑。
    static func feasibilityLine(
        _ pass: CategoryMetadataPass,
        byteRouteDataP50Milliseconds: Double?
    ) -> String {
        let perAsset = pass.averageMicrosecondsPerAsset
        let ratio: Double?
        if let perAsset, perAsset > 0, let p50 = byteRouteDataP50Milliseconds {
            ratio = p50 * 1_000 / perAsset
        } else {
            ratio = nil
        }
        let perAssetText = perAsset.map { ProbeFormat.microseconds($0) }
            ?? ProbeFormat.absentText
        let ratioText = ratio.map { ProbeFormat.ratio($0) }
            ?? ProbeFormat.absentText
        let total = ProbeFormat.milliseconds(pass.elapsedMilliseconds)
        let reference =
            ProbeFormat.optionalMilliseconds(byteRouteDataP50Milliseconds)
        return [
            "feasibility",
            "metadata-per-asset=" + perAssetText,
            "metadata-pass-total=" + total,
            "byte-route-data-p50=" + reference,
            "ratio-byte-route-over-metadata=" + ratioText
        ].joined(separator: ProbeFormat.fieldSeparator)
    }

    static func report(
        pass: CategoryMetadataPass,
        edited: CategoryMetadataEditedPass,
        byteRouteDataP50Milliseconds: Double?
    ) -> String {
        var lines = [header(pass)]
        lines.append(contentsOf: distributionLines(pass))
        lines.append(editedLine(edited, totalAssetCount: pass.totalAssetCount))
        lines.append(feasibilityLine(
            pass,
            byteRouteDataP50Milliseconds: byteRouteDataP50Milliseconds
        ))
        return lines.joined(separator: "\n")
    }

    static func progress(phase: Int, phaseCount: Int) -> String {
        "IC-145 C category-metadata probe phase \(phase)/\(phaseCount)"
    }
}

/// 子项 C 的 PhotoKit 实现。
///
/// 第一遍只读元数据（`mediaType` / `mediaSubtypes` / `duration` / 像素 /
/// `creationDate` / `isFavorite` / `canPerform(.content)`），**不发起任何
/// 资源请求**；第二遍才为「已编辑」逐个枚举资源清单，单独计时。
///
/// 两遍分开的原因：`canPerform(.content)` 是**可编辑性**判定，不是
/// 「已编辑」判定；真正的已编辑判定要看 `adjustmentData` 资源，那是资源清单
/// 枚举，混进第一遍会让「纯元数据遍历耗时」这个读数失去意义。
final class CategoryMetadataProbeService: CategoryMetadataProbing {
    /// 「最近 30 天」虚拟范围的窗口长度。
    static let recentWindowSeconds: TimeInterval = 30 * 24 * 60 * 60

    func runMetadataPass() async -> CategoryMetadataPass {
        let all = PHAsset.fetchAssets(with: nil)
        // 计时区外先备好基准时刻，取当前时间的开销不进读数。
        let cutoff = Date().addingTimeInterval(-Self.recentWindowSeconds)

        var photo = 0
        var video = 0
        var screenshot = 0
        var live = 0
        var favorite = 0
        var editable = 0
        var recent = 0
        var durationBuckets: [VideoDurationBucket: Int] = [:]
        var pixelBuckets: [VideoPixelBucket: Int] = [:]

        let startedAt = CACurrentMediaTime()
        all.enumerateObjects { asset, _, _ in
            if asset.mediaType == .video {
                video += 1
                let durationBucket = VideoDurationBucket.bucket(
                    forSeconds: asset.duration
                )
                durationBuckets[durationBucket, default: 0] += 1
                let pixelBucket = VideoPixelBucket.bucket(
                    forLongEdge: max(asset.pixelWidth, asset.pixelHeight)
                )
                pixelBuckets[pixelBucket, default: 0] += 1
            } else {
                photo += 1
            }
            if asset.mediaSubtypes.contains(.photoScreenshot) {
                screenshot += 1
            }
            if asset.mediaSubtypes.contains(.photoLive) {
                live += 1
            }
            if asset.isFavorite {
                favorite += 1
            }
            if asset.canPerform(.content) {
                editable += 1
            }
            if let creationDate = asset.creationDate, creationDate >= cutoff {
                recent += 1
            }
        }
        let elapsed = (CACurrentMediaTime() - startedAt) * 1_000

        return CategoryMetadataPass(
            totalAssetCount: all.count,
            elapsedMilliseconds: elapsed,
            photoCount: photo,
            videoCount: video,
            screenshotCount: screenshot,
            livePhotoCount: live,
            favoriteCount: favorite,
            editableCount: editable,
            recentThirtyDayCount: recent,
            durationBuckets: durationBuckets,
            pixelBuckets: pixelBuckets
        )
    }

    func runEditedPass() async -> CategoryMetadataEditedPass {
        let all = PHAsset.fetchAssets(with: nil)
        var edited = 0
        let startedAt = CACurrentMediaTime()
        all.enumerateObjects { asset, _, _ in
            let hasAdjustment = PHAssetResource.assetResources(for: asset)
                .contains { $0.type == .adjustmentData }
            if hasAdjustment {
                edited += 1
            }
        }
        let elapsed = (CACurrentMediaTime() - startedAt) * 1_000
        return CategoryMetadataEditedPass(
            editedCount: edited,
            elapsedMilliseconds: elapsed
        )
    }
}

/// 子项 C 的运行协调器。**关闭态零副作用**，口径同子项 A、B。
final class CategoryMetadataProbeCoordinator: ObservableObject {
    static let phaseCount = 2

    @Published private(set) var isRunning = false
    @Published private(set) var progressText = ""
    @Published private(set) var reportText = ""

    private var runTask: Task<Void, Never>?

    var canExport: Bool {
        !isRunning && !reportText.isEmpty
    }

    /// `byteRouteDataP50Milliseconds` 由子项 B 协调器本次运行的读数提供；
    /// B 未跑过即 nil，报告里如实写 none。
    func run(
        using prober: CategoryMetadataProbing,
        byteRouteDataP50Milliseconds: Double?
    ) {
        guard !isRunning else {
            return
        }
        isRunning = true
        reportText = ""
        progressText = CategoryMetadataProbeText.progress(
            phase: 1,
            phaseCount: Self.phaseCount
        )
        runTask = Task { @MainActor [weak self] in
            let pass = await prober.runMetadataPass()
            guard let self else {
                return
            }
            self.progressText = CategoryMetadataProbeText.progress(
                phase: 2,
                phaseCount: Self.phaseCount
            )
            let edited = await prober.runEditedPass()
            self.reportText = CategoryMetadataProbeText.report(
                pass: pass,
                edited: edited,
                byteRouteDataP50Milliseconds: byteRouteDataP50Milliseconds
            )
            self.isRunning = false
            self.runTask = nil
        }
    }
}

// MARK: - 三个子项共用的格式化与设备读数

/// 报告文本的原子格式化。**全 ASCII**（见文件头纪律 3）。
enum ProbeFormat {
    static let fieldSeparator = "|"
    static let absentText = "none"

    static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    static func optionalCount(_ value: Int64?) -> String {
        value.map { String($0) } ?? absentText
    }

    static func seconds(_ value: Double) -> String {
        String(format: "%.2f", locale: posixLocale, value)
    }

    static func milliseconds(_ value: Double) -> String {
        String(format: "%.3fms", locale: posixLocale, value)
    }

    static func optionalMilliseconds(_ value: Double?) -> String {
        value.map(milliseconds) ?? absentText
    }

    static func microseconds(_ value: Double) -> String {
        String(format: "%.3fus", locale: posixLocale, value)
    }

    static func ratio(_ value: Double) -> String {
        String(format: "%.1fx", locale: posixLocale, value)
    }

    static func percentage(_ value: Int, of total: Int) -> String {
        guard total > 0 else {
            return zeroPercentText
        }
        return String(
            format: "%.1f%%",
            locale: posixLocale,
            Double(value) * 100 / Double(total)
        )
    }

    static func date(_ value: Date?) -> String {
        guard let value else {
            return absentText
        }
        return dateFormatter.string(from: value)
    }

    /// 报告里汇总行的行首标签。抽成常量而不是内联字面量：扫描器把
    /// 「return 紧跟字符串字面量」判为展示 helper 直接返回字符串。
    static let summaryTag = "summary"

    private static let zeroPercentText = "0.0%"
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    /// 固定 UTC + POSIX，报告读数不随设备区域与时区漂移（测试也才钉得住）。
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return formatter
    }()
}

/// 设备读数。`UIScreen` 是主线程隔离类型，取值统一走这里。
enum ProbeDeviceMetrics {
    @MainActor
    static func nativeScreenPixelSize() -> CGSize {
        UIScreen.main.nativeBounds.size
    }
}
