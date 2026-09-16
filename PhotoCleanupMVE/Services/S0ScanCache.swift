import Foundation

/// IC-153 B：扫描缓存条目（裁定 四）。
///
/// 按 `localIdentifier` 键——键即缓存字典的键，条目里不再重复存一份。条目的
/// `modificationDate` 与库内当前值相同即复用，不同即重取。
///
/// 日期按 `JSONEncoder` 的默认策略存（浮点秒），**不照 `SessionPersistence` 用
/// iso8601**：iso8601 只保留到整秒，带小数秒的修改时间往返一次就不再相等，
/// 每次启动都会被判成「已改动」而全量重取。
struct S0ScanCacheEntry: Codable, Equatable, Sendable {
    let modificationDate: Date?
    /// `SZ(a)`。未解析时为 0。
    let byteCount: Int64
    let isUnresolved: Bool
    let mediaType: S0ScannedMediaType
    let isScreenshot: Bool
    let pixelWidth: Int
    let pixelHeight: Int
    let duration: TimeInterval
    let videoFilenamePrefixMatched: Bool
    let resolutionMatched: Bool
    let creationDate: Date?
}

extension S0ScanCacheEntry {
    /// 由一遍元数据与一次资源取数拼出条目。`byteCount` 为 nil 即取不到字节：
    /// 记 0 并标未解析（裁定 三）。
    init(
        metadata: S0AssetMetadata,
        byteCount: Int64?,
        evidence: S0ScreenRecordingEvidence
    ) {
        self.init(
            modificationDate: metadata.modificationDate,
            byteCount: byteCount ?? 0,
            isUnresolved: byteCount == nil,
            mediaType: metadata.mediaType,
            isScreenshot: metadata.isScreenshot,
            pixelWidth: metadata.pixelWidth,
            pixelHeight: metadata.pixelHeight,
            duration: metadata.duration,
            videoFilenamePrefixMatched: evidence.filenamePrefixMatched,
            resolutionMatched: evidence.resolutionMatched,
            creationDate: metadata.creationDate
        )
    }

    /// 缓存条目直接进分类：两条录屏证据已随条目存下，不必再有文件名。
    func classified(id: String) -> S0ClassifiedAsset {
        S0ClassifiedAsset(
            id: id,
            byteCount: byteCount,
            isUnresolved: isUnresolved,
            hits: S0ScanClassifier.hits(
                mediaType: mediaType,
                isScreenshot: isScreenshot,
                byteCount: byteCount,
                isUnresolved: isUnresolved,
                evidence: S0ScreenRecordingEvidence(
                    filenamePrefixMatched: videoFilenamePrefixMatched,
                    resolutionMatched: resolutionMatched
                )
            )
        )
    }
}

/// 缓存文件的整体结构。
struct S0ScanCacheFile: Codable, Equatable, Sendable {
    let cacheSchemaVersion: Int
    let entries: [String: S0ScanCacheEntry]
}

/// 先只解版本号：版本不符时条目结构可能已变，不能指望整份还解得开。
private struct S0ScanCacheHeader: Decodable {
    let cacheSchemaVersion: Int
}

/// IC-153 B：缓存文件存取。落点照 `SessionPersistence` 的既有样板——
/// Application Support 下的 `PhotoCleanupMVE` 目录、`.atomic` 写、`NSLock` 保护。
///
/// **构造无副作用**：不建目录、不读文件（C4）。目录在第一次写入时才建。
/// 缓存是加速器不是数据源：读不到、解不开、版本不符一律当空缓存。
final class S0ScanCacheStore {
    static let fileName = "s0-scan-cache.json"
    static let directoryName = "PhotoCleanupMVE"

    let fileURL: URL
    private let directoryURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()

    init(directoryURL: URL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        fileURL = directoryURL.appendingPathComponent(Self.fileName)
    }

    /// 产品落点：`Application Support/PhotoCleanupMVE/s0-scan-cache.json`。
    convenience init(fileManager: FileManager = .default) {
        let root = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        self.init(
            directoryURL: root.appendingPathComponent(
                Self.directoryName,
                isDirectory: true
            ),
            fileManager: fileManager
        )
    }

    func load() -> [String: S0ScanCacheEntry] {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else {
            return [:]
        }
        let decoder = JSONDecoder()
        guard let header = try? decoder.decode(S0ScanCacheHeader.self, from: data),
              header.cacheSchemaVersion == S0ScanRules.cacheSchemaVersion,
              let file = try? decoder.decode(S0ScanCacheFile.self, from: data) else {
            return [:]
        }
        return file.entries
    }

    func save(_ entries: [String: S0ScanCacheEntry]) throws {
        lock.lock()
        defer { lock.unlock() }
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(
            S0ScanCacheFile(
                cacheSchemaVersion: S0ScanRules.cacheSchemaVersion,
                entries: entries
            )
        )
        try data.write(to: fileURL, options: .atomic)
    }
}

/// IC-153 B2：续扫判定（纯函数）。
///
/// 输入「库内当前元数据」与「缓存」，输出四个互不相交的集合：
/// - `reusedIDs`：修改时间相同且已解析——复用，不取字节；
/// - `refetchIDs`：缓存缺失或修改时间不同——新增与改动，要取字节，**计入进度**；
/// - `retryIDs`：修改时间相同但上次未解析——下次机会，要取字节，**不算新增**；
/// - `discardedIDs`：缓存有而库内无——丢弃。
///
/// 任务卡 B2 的「需重取集合」= `refetchIDs` ∪ `retryIDs`。两者分开给出，是因为
/// 裁定 四只让「新条目或改动条目」回报扫描中：未解析的重试若也回扫描中，开了
/// iCloud 优化储存的库每次打开都会重新出现「正在扫描」（H75 第 2、5 条）。
struct S0ScanResumePlan: Equatable, Sendable {
    let reusedIDs: Set<String>
    let refetchIDs: Set<String>
    let retryIDs: Set<String>
    let discardedIDs: Set<String>

    static func make(
        library: [S0AssetMetadata],
        cache: [String: S0ScanCacheEntry]
    ) -> S0ScanResumePlan {
        var reused: Set<String> = []
        var refetch: Set<String> = []
        var retry: Set<String> = []
        var present: Set<String> = []
        for metadata in library {
            let identifier = metadata.localIdentifier
            present.insert(identifier)
            guard let entry = cache[identifier],
                  entry.modificationDate == metadata.modificationDate else {
                refetch.insert(identifier)
                continue
            }
            if entry.isUnresolved {
                retry.insert(identifier)
            } else {
                reused.insert(identifier)
            }
        }
        return S0ScanResumePlan(
            reusedIDs: reused,
            refetchIDs: refetch,
            retryIDs: retry,
            discardedIDs: Set(cache.keys).subtracting(present)
        )
    }
}
