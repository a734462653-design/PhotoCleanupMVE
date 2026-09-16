import Foundation

/// IC-153 A：扫描到的资产只分照片与视频两种。三个类别的判据只认这一刀；
/// PhotoKit 媒体类型的其余取值由源的映射层归入照片（子项 C）。
enum S0ScannedMediaType: String, Codable, Equatable, Sendable {
    case photo
    case video
}

/// 像素尺寸。登记值 `S0ScanRules.screenRecordingPixelSize` 的承载类型。
struct S0ScanPixelSize: Equatable, Sendable {
    let width: Int
    let height: Int

    /// 横竖不限的相等：宽高互换也算同一尺寸。
    func matchesEitherOrientation(width otherWidth: Int, height otherHeight: Int) -> Bool {
        (width == otherWidth && height == otherHeight)
            || (width == otherHeight && height == otherWidth)
    }
}

/// IC-153 A：分类与聚合的输入模型（本卡自定义，放 `Services/`，不进 `Core/`）。
struct S0ScannedAsset: Equatable, Sendable {
    let id: String
    let modificationDate: Date?
    let creationDate: Date?
    let mediaType: S0ScannedMediaType
    let isScreenshot: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    /// 视频主资源的原始文件名。只对视频取（裁定 三），照片恒为 nil。
    let videoFilename: String?
    /// `SZ(a)`。取不到字节时记 0。
    let byteCount: Int64
    /// 取不到字节（典型：iCloud 优化储存且本机无原件）。不进任何类别、不计入 `LIB`，
    /// 下次扫描时重试（裁定 三）。
    let isUnresolved: Bool
}

/// 屏幕录制的两条证据。缓存只存这两个布尔、不存文件名（裁定 四）。
struct S0ScreenRecordingEvidence: Equatable, Sendable {
    let filenamePrefixMatched: Bool
    let resolutionMatched: Bool
}

/// 已分类的资产：聚合只认这四项，与它来自新取数还是来自缓存无关。
struct S0ClassifiedAsset: Equatable, Sendable {
    let id: String
    let byteCount: Int64
    let isUnresolved: Bool
    let hits: Set<S0CategoryIdentifier>
}

/// IC-153 A：单资产 → 类别命中集合；命中集合 + 优先序 → 去重归属；排除规则。
///
/// 纯函数、零 PhotoKit。门槛与前缀一律经 `S0ScanRules`，本文件不写裸数。
enum S0ScanClassifier {
    /// 归属优先序（SPEC-S0 v2 第二节第 2 部分）。本卡只实装前三个类别，重复与
    /// 相似不出现（裁定 二）。同时也是快照 `categories` 的给出顺序——排序由状态机
    /// 做，这里不排。
    static let attributionPriority: [S0CategoryIdentifier] = [
        .bigVideo,
        .screenRecording,
        .screenshot
    ]

    /// 屏幕录制的两条证据。照片一律两个假：录屏判据只对视频成立，而本机截屏的
    /// 像素恰好也是登记尺寸，不先分视频就会把截图当成录屏的证据存进缓存。
    static func screenRecordingEvidence(
        mediaType: S0ScannedMediaType,
        videoFilename: String?,
        pixelWidth: Int,
        pixelHeight: Int
    ) -> S0ScreenRecordingEvidence {
        guard mediaType == .video else {
            return S0ScreenRecordingEvidence(
                filenamePrefixMatched: false,
                resolutionMatched: false
            )
        }
        let prefixMatched = videoFilename.map {
            $0.hasPrefix(S0ScanRules.screenRecordingFilenamePrefix)
        } ?? false
        let resolutionMatched = S0ScanRules.screenRecordingPixelSize
            .matchesEitherOrientation(width: pixelWidth, height: pixelHeight)
        return S0ScreenRecordingEvidence(
            filenamePrefixMatched: prefixMatched,
            resolutionMatched: resolutionMatched
        )
    }

    /// A1 类别命中。每条资产可命中多个；未解析的资产不命中任何类别。
    static func hits(
        mediaType: S0ScannedMediaType,
        isScreenshot: Bool,
        byteCount: Int64,
        isUnresolved: Bool,
        evidence: S0ScreenRecordingEvidence
    ) -> Set<S0CategoryIdentifier> {
        guard !isUnresolved else {
            return []
        }
        var hits: Set<S0CategoryIdentifier> = []
        if isScreenshot {
            hits.insert(.screenshot)
        }
        if mediaType == .video {
            if evidence.filenamePrefixMatched || evidence.resolutionMatched {
                hits.insert(.screenRecording)
            }
            if byteCount >= S0ScanRules.bigVideoMinimumByteCount {
                hits.insert(.bigVideo)
            }
        }
        return hits
    }

    static func hits(for asset: S0ScannedAsset) -> Set<S0CategoryIdentifier> {
        hits(
            mediaType: asset.mediaType,
            isScreenshot: asset.isScreenshot,
            byteCount: asset.byteCount,
            isUnresolved: asset.isUnresolved,
            evidence: screenRecordingEvidence(
                mediaType: asset.mediaType,
                videoFilename: asset.videoFilename,
                pixelWidth: asset.pixelWidth,
                pixelHeight: asset.pixelHeight
            )
        )
    }

    static func classified(_ asset: S0ScannedAsset) -> S0ClassifiedAsset {
        S0ClassifiedAsset(
            id: asset.id,
            byteCount: asset.byteCount,
            isUnresolved: asset.isUnresolved,
            hits: hits(for: asset)
        )
    }

    /// A2 去重归属：命中多个时按优先序取最高；一个都没命中为 nil。
    static func primaryCategory(
        for hits: Set<S0CategoryIdentifier>
    ) -> S0CategoryIdentifier? {
        attributionPriority.first { hits.contains($0) }
    }

    /// A3 排除规则：`D_全部` 内、账本内、未解析的资产一律不进任何 `c.assets`。
    /// 隐藏与「最近删除」不在这里判——源的枚举层根本不交出它们（子项 C）。
    static func isExcludedFromCategories(
        _ asset: S0ClassifiedAsset,
        pendingDeletionAssetIDs: Set<String>,
        ledgerAssetIDs: Set<String>
    ) -> Bool {
        asset.isUnresolved
            || pendingDeletionAssetIDs.contains(asset.id)
            || ledgerAssetIDs.contains(asset.id)
    }
}

/// 聚合时的上下文：进度、识别阶段与两个排除集合，其余照原样带进快照。
struct S0ScanAggregationContext: Equatable, Sendable {
    let progress: S0ScanProgress
    let recognition: S0CategoryRecognition
    /// `D_全部`。会话层的唯一定义处在 SPEC-S1 v9 第二节，S0 不另持一份。
    let pendingDeletionAssetIDs: Set<String>
    /// 账本内的资产。账本写入方是批次 5.3，本卡服务恒传空集。
    let ledgerAssetIDs: Set<String>
    let ledgerEntries: [S0LedgerEntry]
    let isLimitedAuthorization: Bool
}

/// IC-153 A4：聚合。
///
/// - `c.count`／`c.bytes` 按**全量**（同一资产可计入多个类别）；
/// - `cleanableAssetCount`／`cleanableByteCount` 按**去重归属**，每条资产只计一次；
/// - `LIB` = 全部已解析资产的字节和，含不属任何类别的、含 `D_全部` 内的；
/// - `pendingDeletionByteCount` = `D_全部` 内已解析资产的字节和；
/// - `categories` 恒为三条，顺序即归属优先序。
enum S0ScanAggregator {
    static func snapshot(
        of assets: [S0ClassifiedAsset],
        context: S0ScanAggregationContext
    ) -> S0CleanupSnapshot {
        var libraryByteCount: Int64 = 0
        var pendingDeletionByteCount: Int64 = 0
        var cleanableAssetCount = 0
        var cleanableByteCount: Int64 = 0
        var candidateCounts: [S0CategoryIdentifier: Int] = [:]
        var candidateByteCounts: [S0CategoryIdentifier: Int64] = [:]

        for asset in assets where !asset.isUnresolved {
            libraryByteCount += asset.byteCount
            if context.pendingDeletionAssetIDs.contains(asset.id) {
                pendingDeletionByteCount += asset.byteCount
            }
            guard !S0ScanClassifier.isExcludedFromCategories(
                asset,
                pendingDeletionAssetIDs: context.pendingDeletionAssetIDs,
                ledgerAssetIDs: context.ledgerAssetIDs
            ), S0ScanClassifier.primaryCategory(for: asset.hits) != nil else {
                continue
            }
            cleanableAssetCount += 1
            cleanableByteCount += asset.byteCount
            for identifier in asset.hits {
                candidateCounts[identifier, default: 0] += 1
                candidateByteCounts[identifier, default: 0] += asset.byteCount
            }
        }

        let categories = S0ScanClassifier.attributionPriority.map { identifier in
            S0CategorySnapshot(
                id: identifier,
                candidateCount: candidateCounts[identifier] ?? 0,
                candidateByteCount: candidateByteCounts[identifier] ?? 0,
                recognition: context.recognition
            )
        }
        return S0CleanupSnapshot(
            progress: context.progress,
            cleanableAssetCount: cleanableAssetCount,
            cleanableByteCount: cleanableByteCount,
            libraryTotalByteCount: libraryByteCount,
            categories: categories,
            ledgerEntries: context.ledgerEntries,
            pendingDeletionByteCount: pendingDeletionByteCount,
            isLimitedAuthorization: context.isLimitedAuthorization
        )
    }
}
