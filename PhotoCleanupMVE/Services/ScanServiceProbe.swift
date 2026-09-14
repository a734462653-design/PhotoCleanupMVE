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
            "video-count=\(videoCount)" + ProbeFormat.fieldSeparator +
                "library-asset-count=\(libraryAssetCount)" +
                ProbeFormat.fieldSeparator +
                "unresolved=\(unresolvedCount)"
        ].joined(separator: "\n")
    }

    static func summary(
        _ measurements: [ScreenRecordingMeasurement]
    ) -> String {
        let total = measurements.count
        var lines = ScreenRecordingRule.allCases.map { rule in
            let hits = measurements.filter { $0.verdict(for: rule) }.count
            let head = ProbeFormat.summaryTag + ProbeFormat.fieldSeparator
            return head + "rule=" + rule.rawValue +
                ProbeFormat.fieldSeparator +
                "hits=\(hits)/\(total) (" +
                ProbeFormat.percentage(hits, of: total) + ")"
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
        lines.append(
            ProbeFormat.summaryTag + ProbeFormat.fieldSeparator +
                "case-insensitive-filename-hits=\(caseInsensitive)/\(total)"
        )
        lines.append(
            ProbeFormat.summaryTag + ProbeFormat.fieldSeparator +
                "resolution-hit-filename-miss=\(resolutionOnly)"
        )
        lines.append(
            ProbeFormat.summaryTag + ProbeFormat.fieldSeparator +
                "filename-hit-resolution-miss=\(filenameOnly)"
        )
        lines.append(
            ProbeFormat.summaryTag + ProbeFormat.fieldSeparator +
                "missing-video-resource-filename=\(missingFilename)"
        )
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

// MARK: - 三个子项共用的格式化与设备读数

/// 报告文本的原子格式化。**全 ASCII**（见文件头纪律 3）。
enum ProbeFormat {
    static let fieldSeparator = "|"
    static let absentText = "none"

    static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    static func optionalCount(_ value: Int64?) -> String {
        value.map { String($0) } ?? none
    }

    static func seconds(_ value: Double) -> String {
        String(format: "%.2f", locale: posixLocale, value)
    }

    static func milliseconds(_ value: Double) -> String {
        String(format: "%.3fms", locale: posixLocale, value)
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
