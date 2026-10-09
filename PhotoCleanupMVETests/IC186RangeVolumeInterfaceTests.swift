import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-186：S1 重设计批第一张——范围体积接口（SPEC-S1 v12 第二节 `体积(r)`、`U` 与 `总占用`、`占比(r)`）。
/// 1 纯口径：体积 = 范围内 `SZ` 之和、有一张不在表里即未知；总占用；占比四舍五入并钳 0～100。
/// 2 扫描服务读口：只在当前一遍已完成时给表；键 = 库内全部资产，含待删篮的、未解析记 0；
///   第二遍有新增时回到扫描中即没有表，完成后新表含新增、不含已删；失败没有表。
/// 3 源码落位：读口只在服务具体类型上（不进协议、桩；IC-191 起 App 把它接到 S1 状态机），Core 新文件只依赖 Foundation。
///
/// **夹具驱动**：夹具源不是 PhotoKit；界面与接线归 V1 视图卡，本卡无人工判定项。
final class IC186RangeVolumeInterfaceTests: XCTestCase {
    private static let volumesPath = "PhotoCleanupMVE/Core/S1RangeVolumes.swift"
    private static let servicePath = "PhotoCleanupMVE/Services/S0LibraryScanService.swift"
    private static let providerPath = "PhotoCleanupMVE/Features/S0/S0CleanupDataProviding.swift"
    private static let stubPath = "PhotoCleanupMVE/Services/S0CleanupDataStub.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"

    // MARK: - 断言 1：纯口径

    func testIC186A_TableArithmetic() {
        let table = S1AssetByteCountTable(byteCountByAssetID: ["a": 125, "b": 250, "c": 0, "d": 625])
        XCTAssertEqual(table.totalByteCount, 1_000)

        XCTAssertEqual(table.volume(of: range("r1", ["a", "b"])), 375)
        XCTAssertEqual(table.volume(of: range("r2", ["c"])), 0)
        XCTAssertEqual(table.volume(of: range("r3", [])), 0)
        // 有一张不在表里即未知，不给已知部分之和。
        XCTAssertNil(table.volume(of: range("r4", ["a", "x"])))

        // 年 = 各月之并时，年体积 = 各月体积之和。
        let monthOne = range("m1", ["a"])
        let monthTwo = range("m2", ["b", "c"])
        let year = range("y", ["a", "b", "c"])
        XCTAssertEqual(table.volume(of: year), 375)
        XCTAssertEqual(
            table.volume(of: year),
            (table.volume(of: monthOne) ?? -1) + (table.volume(of: monthTwo) ?? -1)
        )

        // 占比：四舍五入、远离零（0.125 与 0.375 在二进制里精确）；钳 0～100；总占用为 0 得 0。
        XCTAssertEqual(table.sharePercent(ofVolume: 125), 13)
        XCTAssertEqual(table.sharePercent(ofVolume: 375), 38)
        XCTAssertEqual(table.sharePercent(ofVolume: 333), 33)
        XCTAssertEqual(table.sharePercent(ofVolume: 0), 0)
        XCTAssertEqual(table.sharePercent(ofVolume: 1_000), 100)
        XCTAssertEqual(table.sharePercent(ofVolume: 1_500), 100)
        XCTAssertEqual(table.sharePercent(ofVolume: -5), 0)
        let empty = S1AssetByteCountTable(byteCountByAssetID: [:])
        XCTAssertEqual(empty.totalByteCount, 0)
        XCTAssertEqual(empty.sharePercent(ofVolume: 0), 0)
    }

    // MARK: - 断言 2：扫描服务读口

    func testIC186B_ServiceTableFollowsScanOutcome() throws {
        let fixture = VolumeFixture(
            assets: [metadata("p1"), metadata("p2"), metadata("p3"), metadata("v1", isVideo: true)],
            byteCounts: ["p1": 3_000_000, "p2": 2_000_000, "v1": 120_000_000]
        )
        let service = S0LibraryScanService(
            source: fixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: makeTemporaryDirectory())
        )
        service.pendingDeletionAssetIDs = { ["p2"] }

        // 未推进：回报扫描中，没有表。
        XCTAssertEqual(service.currentScanOutcome(), .scanning)
        XCTAssertNil(service.assetByteCountTable())

        // 一遍完成：库内全部资产在表里——待删篮的 p2 照记真实字节，未解析的 p3 记 0。
        service.advanceScan()
        XCTAssertTrue(waitUntil { !service.isScanInFlight })
        XCTAssertEqual(service.currentScanOutcome(), .completed)
        let table = try XCTUnwrap(service.assetByteCountTable())
        XCTAssertEqual(
            table.byteCountByAssetID,
            ["p1": 3_000_000, "p2": 2_000_000, "p3": 0, "v1": 120_000_000]
        )
        XCTAssertEqual(table.totalByteCount, 125_000_000)
        // 与首页口径对账（账本恒空）：`LIB`（不含篮、不含未解析）+ 待删篮字节 = 总占用。
        let snapshot = service.currentSnapshot()
        XCTAssertEqual(
            snapshot.libraryTotalByteCount + snapshot.pendingDeletionByteCount,
            table.totalByteCount
        )
        // 修订号未变，再读同一张表。
        XCTAssertEqual(service.assetByteCountTable(), table)

        // 第二遍：p3 已删、n1 新增且取字节卡住——回报回到扫描中，没有表。
        fixture.replaceLibrary(
            assets: [metadata("p1"), metadata("p2"), metadata("v1", isVideo: true), metadata("n1")],
            byteCounts: ["p1": 3_000_000, "p2": 2_000_000, "v1": 120_000_000, "n1": 5_000_000]
        )
        fixture.setBlocked(true)
        service.advanceScan()
        XCTAssertTrue(waitUntil { service.currentScanOutcome() == .scanning })
        XCTAssertNil(service.assetByteCountTable())

        // 放行：新表含新增、不含已删。
        fixture.setBlocked(false)
        XCTAssertTrue(waitUntil { !service.isScanInFlight })
        XCTAssertEqual(service.currentScanOutcome(), .completed)
        let second = try XCTUnwrap(service.assetByteCountTable())
        XCTAssertEqual(
            second.byteCountByAssetID,
            ["p1": 3_000_000, "p2": 2_000_000, "v1": 120_000_000, "n1": 5_000_000]
        )
        XCTAssertEqual(second.totalByteCount, 130_000_000)

        // 失败（授权不可读）：没有表。
        let deniedFixture = VolumeFixture(
            assets: [metadata("p1")],
            byteCounts: ["p1": 3_000_000],
            authorization: .denied
        )
        let denied = S0LibraryScanService(
            source: deniedFixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: makeTemporaryDirectory())
        )
        denied.advanceScan()
        XCTAssertTrue(waitUntil { !denied.isScanInFlight })
        XCTAssertEqual(denied.currentScanOutcome(), .failed(.authorization))
        XCTAssertNil(denied.assetByteCountTable())
    }

    // MARK: - 断言 3：源码落位

    func testIC186C_SourceDiscipline() throws {
        let service = try XCTUnwrap(strippedSource(Self.servicePath))
        XCTAssertEqual(occurrences(of: "func assetByteCountTable() -> S1AssetByteCountTable? {", in: service), 1)
        XCTAssertEqual(occurrences(of: "guard outcome == .completed else {", in: service), 1)
        XCTAssertEqual(occurrences(of: "memoizedByteCountTable", in: service), 3)
        XCTAssertEqual(occurrences(of: "for identifier in libraryIdentifiers {", in: service), 1)
        // 既有钉子不受影响：纯内存投影、不按标识查 PhotoKit、归属判定仍只一处调用。
        XCTAssertEqual(occurrences(of: "withLocalIdentifiers", in: service), 0)
        XCTAssertEqual(occurrences(of: "PHAsset.fetchAssets(with: nil)", in: service), 1)
        XCTAssertEqual(occurrences(of: "attributedCategory(", in: service), 1)

        // 读口只在服务具体类型上：不进协议、不进桩。IC-191：App 把它接到 S1 状态机的读口——只调一次、不写类型名。
        for path in [Self.providerPath, Self.stubPath] {
            let text = try XCTUnwrap(strippedSource(path), path)
            XCTAssertEqual(occurrences(of: "assetByteCountTable", in: text), 0, path)
            XCTAssertEqual(occurrences(of: "S1AssetByteCountTable", in: text), 0, path)
        }
        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "assetByteCountTable", in: app), 1)
        XCTAssertEqual(occurrences(of: "S1AssetByteCountTable", in: app), 0)

        // Core 新文件只依赖 Foundation，不碰 PhotoKit、不引用 S0 类型、不取文案。
        let volumesRaw = try XCTUnwrap(sourceText(Self.volumesPath))
        let volumes = try XCTUnwrap(strippedSource(Self.volumesPath))
        XCTAssertEqual(occurrences(of: "import ", in: volumesRaw), 1)
        XCTAssertEqual(occurrences(of: "import Foundation", in: volumesRaw), 1)
        for needle in ["Photos", "PHAsset", "S0", "L10n.", "@MainActor"] {
            XCTAssertEqual(occurrences(of: needle, in: volumes), 0, needle)
        }
        XCTAssertEqual(occurrences(of: "struct S1AssetByteCountTable: Equatable, Sendable {", in: volumes), 1)
        XCTAssertEqual(occurrences(of: "func volume(of range: S1Range) -> Int64? {", in: volumes), 1)
        XCTAssertEqual(occurrences(of: "func sharePercent(ofVolume volume: Int64) -> Int {", in: volumes), 1)
    }

    // MARK: - 夹具

    private func range(_ id: String, _ assetIDs: [String]) -> S1Range {
        S1Range(id: id, displayName: id, assetIDsNewestFirst: assetIDs)
    }

    private func metadata(_ id: String, isVideo: Bool = false) -> S0AssetMetadata {
        S0AssetMetadata(
            localIdentifier: id,
            modificationDate: Date(timeIntervalSinceReferenceDate: 780_000_000.25),
            creationDate: Date(timeIntervalSinceReferenceDate: 780_000_000),
            mediaType: isVideo ? .video : .photo,
            isScreenshot: false,
            pixelWidth: isVideo ? 3_840 : 4_032,
            pixelHeight: isVideo ? 2_160 : 3_024,
            duration: isVideo ? 30 : 0
        )
    }

    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
        super.tearDown()
    }

    /// 只给出路径、不建目录：缓存仓库第一次写入时才建。
    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IC186-" + UUID().uuidString, isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    /// 转主线程 run loop 直到条件成立或超时（服务的回报经主队列送达）。
    @discardableResult
    private func waitUntil(
        timeout: TimeInterval = 10,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            if Date() >= deadline {
                return false
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        return true
    }

    // MARK: - 工具（与既有测试同口径）

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
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}

/// 夹具源：库内资产与字节可整体替换；取字节可整体卡住直到放行或任务被取消。
/// 字节表里没有的资产取不到字节（未解析）。
private final class VolumeFixture {
    private let lock = NSLock()
    private var authorization: S1AuthorizationState
    private var assets: [S0AssetMetadata]
    private var byteCounts: [String: Int64]
    private var blocked = false

    init(
        assets: [S0AssetMetadata],
        byteCounts: [String: Int64],
        authorization: S1AuthorizationState = .authorized
    ) {
        self.assets = assets
        self.byteCounts = byteCounts
        self.authorization = authorization
    }

    func replaceLibrary(assets: [S0AssetMetadata], byteCounts: [String: Int64]) {
        locked { () -> Void in
            self.assets = assets
            self.byteCounts = byteCounts
        }
    }

    func setBlocked(_ value: Bool) {
        locked { () -> Void in
            blocked = value
        }
    }

    func makeSource() -> S0LibraryScanSource {
        S0LibraryScanSource(
            authorizationState: { [self] in
                self.locked { self.authorization }
            },
            enumerateAssets: { [self] in
                self.locked { self.assets }
            },
            fetchResourcesAndBytes: { [self] identifier in
                while !Task.isCancelled, self.locked({ self.blocked }) {
                    try? await Task.sleep(nanoseconds: 2_000_000)
                }
                let byteCount = self.locked { self.byteCounts[identifier] }
                return (videoFilename: nil, byteCount: byteCount)
            }
        )
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try body()
    }
}
