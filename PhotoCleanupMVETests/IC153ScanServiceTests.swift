import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-153：批次 5.1 扫描服务——全库增量扫描、持久缓存、三个元数据类别，替换 S0
/// 数据源桩。
///
/// 依据 SPEC-S0 v2（SHA-256 `8A8E…6F44`）第二节第 2／3 部分、第三节 S0-1、
/// 第十二节第 4 条，与任务卡 IC-20260916-153 的六条裁定。断言编号与任务卡一一
/// 对应：1～3 属子项 A，4～7 属子项 B，8～12 属子项 C，13 属子项 D。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：夹具源不是 PhotoKit。首扫耗时、iCloud
/// 取不到字节的比例、屏幕录制的漏认率、前台恢复的观感只有 H75 能判。
final class IC153ScanServiceTests: XCTestCase {

    // MARK: - 断言 1：单资产命中集合与去重归属（子项 A）

    func testIC153A_ClassifierHitsAndPriority() {
        let megabyte: Int64 = 1_000_000
        let threshold = S0ScanRules.bigVideoMinimumByteCount
        // G874：裁定 一（④ Lynn 2026-09-16），执行端不得改动。
        XCTAssertEqual(threshold, 100_000_000)
        XCTAssertEqual(
            S0ScanClassifier.attributionPriority,
            [.bigVideo, .screenRecording, .screenshot]
        )

        // 普通照片：不属任何类别。
        assertClassification(
            scannedAsset("plain-photo", mediaType: .photo, byteCount: 4 * megabyte),
            hits: [],
            primary: nil
        )
        // 截图：像素恰是录屏登记尺寸，但它是照片——不得命中录屏。
        assertClassification(
            scannedAsset(
                "screenshot",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 2 * megabyte
            ),
            hits: [.screenshot],
            primary: .screenshot
        )
        // 小视频。
        assertClassification(
            scannedAsset(
                "small-video",
                mediaType: .video,
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                videoFilename: "IMG_0001.MOV",
                byteCount: 20 * megabyte
            ),
            hits: [],
            primary: nil
        )
        // 不低于门槛的普通视频。
        assertClassification(
            scannedAsset(
                "big-video",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0002.MOV",
                byteCount: 150 * megabyte
            ),
            hits: [.bigVideo],
            primary: .bigVideo
        )
        // 不低于门槛且文件名前缀命中的录屏：两个类别都命中，去重归大视频。
        assertClassification(
            scannedAsset(
                "prefix-recording",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                byteCount: 120 * megabyte
            ),
            hits: [.bigVideo, .screenRecording],
            primary: .bigVideo
        )
        // 像素 2622×1206（横放）且文件名不命中的录屏。
        assertClassification(
            scannedAsset(
                "resolution-recording",
                mediaType: .video,
                pixelWidth: 2_622,
                pixelHeight: 1_206,
                videoFilename: "IMG_0003.MP4",
                byteCount: 30 * megabyte
            ),
            hits: [.screenRecording],
            primary: .screenRecording
        )
        // 未解析的大视频：证据齐全也不命中任何类别。
        assertClassification(
            scannedAsset(
                "unresolved-video",
                mediaType: .video,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                videoFilename: "ScreenRecording_09-01-2025 08-00-00_1.mp4",
                byteCount: threshold,
                isUnresolved: true
            ),
            hits: [],
            primary: nil
        )
        // 前缀判据大小写敏感：小写前缀不命中。
        assertClassification(
            scannedAsset(
                "lowercase-prefix",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "screenrecording_10-13-2025 15-42-39_1.mp4",
                byteCount: 10 * megabyte
            ),
            hits: [],
            primary: nil
        )
        // 门槛恰好相等时命中（大于等于）。
        assertClassification(
            scannedAsset(
                "at-threshold",
                mediaType: .video,
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                videoFilename: "IMG_0004.MOV",
                byteCount: threshold
            ),
            hits: [.bigVideo],
            primary: .bigVideo
        )
        // 差一个字节不命中。
        assertClassification(
            scannedAsset(
                "below-threshold",
                mediaType: .video,
                pixelWidth: 1_920,
                pixelHeight: 1_080,
                videoFilename: "IMG_0005.MOV",
                byteCount: threshold - 1
            ),
            hits: [],
            primary: nil
        )

        // 两条录屏证据分开记（缓存只存这两个布尔）。
        XCTAssertEqual(
            S0ScanClassifier.screenRecordingEvidence(
                mediaType: .video,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                pixelWidth: 886,
                pixelHeight: 1_920
            ),
            S0ScreenRecordingEvidence(filenamePrefixMatched: true, resolutionMatched: false)
        )
        XCTAssertEqual(
            S0ScanClassifier.screenRecordingEvidence(
                mediaType: .video,
                videoFilename: nil,
                pixelWidth: 1_206,
                pixelHeight: 2_622
            ),
            S0ScreenRecordingEvidence(filenamePrefixMatched: false, resolutionMatched: true)
        )
        XCTAssertEqual(
            S0ScanClassifier.screenRecordingEvidence(
                mediaType: .photo,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                pixelWidth: 1_206,
                pixelHeight: 2_622
            ),
            S0ScreenRecordingEvidence(filenamePrefixMatched: false, resolutionMatched: false)
        )

        // 优先序：三个都中取大视频，后两个中取录屏，只中截图取截图。
        XCTAssertEqual(
            S0ScanClassifier.primaryCategory(for: [.screenshot, .screenRecording, .bigVideo]),
            .bigVideo
        )
        XCTAssertEqual(
            S0ScanClassifier.primaryCategory(for: [.screenshot, .screenRecording]),
            .screenRecording
        )
        XCTAssertNil(S0ScanClassifier.primaryCategory(for: []))
        // 本卡不识别的两个类别不参与归属（裁定 二）。
        XCTAssertNil(S0ScanClassifier.primaryCategory(for: [.duplicate, .similar]))
    }

    // MARK: - 断言 2：hero 去重、类别全量（子项 A）

    func testIC153A_AggregationDedupesHeroButNotCategories() {
        let megabyte: Int64 = 1_000_000
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
        let assets: [S0ClassifiedAsset] = [
            recording,
            screenshot,
            plainPhoto,
            pendingScreenshot,
            ledgerVideo,
            unresolvedVideo
        ].map { S0ScanClassifier.classified($0) }

        let ledgerEntry = S0LedgerEntry(
            categoryID: .bigVideo,
            byteCount: 200 * megabyte,
            committedAt: Date(timeIntervalSince1970: 1_789_344_000),
            availableCapacityBaseline: 6_000_000_000
        )
        let context = S0ScanAggregationContext(
            progress: S0ScanProgress(scannedAssetCount: 6, totalAssetCount: 9),
            recognition: .counting,
            pendingDeletionAssetIDs: ["pending-screenshot", "not-scanned-yet"],
            ledgerAssetIDs: ["ledger-video"],
            ledgerEntries: [ledgerEntry],
            isLimitedAuthorization: true
        )
        let snapshot = S0ScanAggregator.snapshot(of: assets, context: context)

        // 类别全量：录屏同时计入大视频与屏幕录制两个类别。
        let expectedCategories = [
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 1,
                candidateByteCount: 150 * megabyte,
                recognition: .counting,
                coverAssetID: "recording"
            ),
            S0CategorySnapshot(
                id: .screenRecording,
                candidateCount: 1,
                candidateByteCount: 150 * megabyte,
                recognition: .counting,
                coverAssetID: "recording"
            ),
            S0CategorySnapshot(
                id: .screenshot,
                candidateCount: 1,
                candidateByteCount: 3 * megabyte,
                recognition: .counting,
                coverAssetID: "screenshot"
            )
        ]
        XCTAssertEqual(snapshot.categories, expectedCategories)
        // hero 去重：录屏只计一次。
        XCTAssertEqual(snapshot.cleanableAssetCount, 2)
        XCTAssertEqual(snapshot.cleanableByteCount, 153 * megabyte)
        let categorySum = snapshot.categories.reduce(Int64(0)) { total, category in
            total + category.candidateByteCount
        }
        XCTAssertEqual(categorySum, 303 * megabyte)
        XCTAssertGreaterThan(categorySum, snapshot.cleanableByteCount)

        // LIB 含不属任何类别的照片、含待删篮与账本内的资产；未解析的不进。
        XCTAssertEqual(snapshot.libraryTotalByteCount, 359 * megabyte)
        // 待删篮体积：只算已扫到且已解析的那一条。
        XCTAssertEqual(snapshot.pendingDeletionByteCount, 2 * megabyte)

        // 其余字段照原样带进快照。
        XCTAssertEqual(snapshot.progress, context.progress)
        XCTAssertEqual(snapshot.ledgerEntries, [ledgerEntry])
        XCTAssertTrue(snapshot.isLimitedAuthorization)

        // 排除集合清空后，被排除的两条回到各自类别（正对照：排除确实生效）。
        let unfiltered = S0ScanAggregator.snapshot(
            of: assets,
            context: S0ScanAggregationContext(
                progress: context.progress,
                recognition: .settled,
                pendingDeletionAssetIDs: [],
                ledgerAssetIDs: [],
                ledgerEntries: [],
                isLimitedAuthorization: false
            )
        )
        XCTAssertEqual(unfiltered.categories.map { $0.candidateCount }, [2, 1, 2])
        XCTAssertEqual(unfiltered.cleanableAssetCount, 4)
        XCTAssertEqual(unfiltered.cleanableByteCount, 355 * megabyte)
        XCTAssertEqual(unfiltered.libraryTotalByteCount, 359 * megabyte)
        XCTAssertEqual(unfiltered.pendingDeletionByteCount, 0)
        XCTAssertEqual(
            unfiltered.categories.map { $0.recognition },
            [.settled, .settled, .settled]
        )
        XCTAssertEqual(
            unfiltered.categories.map { $0.id },
            [.bigVideo, .screenRecording, .screenshot]
        )
    }

    // MARK: - 断言 3：规则登记制，分类与聚合不写裸数（子项 A）

    func testIC153A_RulesAreRegisteredNotBare() throws {
        let classifier = try XCTUnwrap(strippedSource(Self.classifierPath))
        let literals = numericLiterals(in: classifier)
        let allowed: Set<String> = ["0", "1"]
        XCTAssertTrue(
            literals.isSubset(of: allowed),
            "分类与聚合代码出现了登记表之外的裸数："
                + literals.subtracting(allowed).sorted().joined(separator: ",")
        )
        // 正对照：分类器确实经登记表取值。
        XCTAssertGreaterThanOrEqual(occurrences(of: "S0ScanRules.", in: classifier), 3)

        // 登记表：恰七个常量，每个定义处都注明出处。
        let rules = try XCTUnwrap(sourceText(Self.rulesPath))
        let lines = rules.components(separatedBy: Self.newline)
        var constantCount = 0
        for (index, line) in lines.enumerated() where line.contains("static let ") {
            constantCount += 1
            var cursor = index - 1
            var hasProvenance = false
            while cursor >= 0,
                  lines[cursor].trimmingCharacters(in: .whitespaces).hasPrefix("///") {
                if lines[cursor].contains("出处：") {
                    hasProvenance = true
                }
                cursor -= 1
            }
            XCTAssertTrue(hasProvenance, "登记常量缺出处注释：" + line)
        }
        XCTAssertEqual(constantCount, 7)
        XCTAssertEqual(occurrences(of: "出处：", in: rules), 7)

        // 正对照：同一个数字扫描器在登记表上确实看得见数。
        let rulesStripped = try XCTUnwrap(strippedSource(Self.rulesPath))
        let expectedRuleNumbers: Set<String> = ["100000000", "1206", "2622", "200"]
        XCTAssertTrue(numericLiterals(in: rulesStripped).isSuperset(of: expectedRuleNumbers))

        // 七个取值逐个钉住（任务卡白名单）。
        XCTAssertEqual(S0ScanRules.bigVideoMinimumByteCount, 100_000_000)
        XCTAssertEqual(S0ScanRules.screenRecordingFilenamePrefix, "ScreenRecording_")
        XCTAssertEqual(
            S0ScanRules.screenRecordingPixelSize,
            S0ScanPixelSize(width: 1_206, height: 2_622)
        )
        XCTAssertEqual(S0ScanRules.cacheSchemaVersion, 1)
        XCTAssertEqual(S0ScanRules.persistEveryAssets, 200)
        XCTAssertEqual(S0ScanRules.byteFetchConcurrency, 4)
        XCTAssertEqual(S0ScanRules.snapshotThrottleHz, 4)
    }

    // MARK: - 断言 4：缓存往返与版本号（子项 B）

    func testIC153B_CacheRoundTripAndSchemaVersion() throws {
        let directory = makeTemporaryDirectory()
        let store = S0ScanCacheStore(directoryURL: directory)
        XCTAssertEqual(store.fileURL.lastPathComponent, "s0-scan-cache.json")
        // 没有文件时读回空缓存，且读不建任何东西。
        XCTAssertEqual(store.load(), [:])
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))

        // 修改时间带小数秒：iso8601 往返会丢，这里必须逐位相等。
        let video = S0ScanCacheEntry(
            modificationDate: Date(timeIntervalSinceReferenceDate: 780_000_123.456_789),
            byteCount: 150_000_000,
            isUnresolved: false,
            mediaType: .video,
            isScreenshot: false,
            pixelWidth: 886,
            pixelHeight: 1_920,
            duration: 42.5,
            videoFilenamePrefixMatched: true,
            resolutionMatched: false,
            creationDate: Date(timeIntervalSinceReferenceDate: 779_999_000.987_654)
        )
        let unresolvedPhoto = S0ScanCacheEntry(
            modificationDate: nil,
            byteCount: 0,
            isUnresolved: true,
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            duration: 0,
            videoFilenamePrefixMatched: false,
            resolutionMatched: false,
            creationDate: nil
        )
        let entries = ["video-a/L0/001": video, "photo-b/L0/001": unresolvedPhoto]
        try store.save(entries)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))

        let reloaded = S0ScanCacheStore(directoryURL: directory).load()
        XCTAssertEqual(reloaded, entries)
        let reloadedVideo = try XCTUnwrap(reloaded["video-a/L0/001"])
        XCTAssertEqual(reloadedVideo.modificationDate, video.modificationDate)
        XCTAssertEqual(reloadedVideo.byteCount, video.byteCount)
        XCTAssertEqual(reloadedVideo.isUnresolved, video.isUnresolved)
        XCTAssertEqual(reloadedVideo.mediaType, video.mediaType)
        XCTAssertEqual(reloadedVideo.isScreenshot, video.isScreenshot)
        XCTAssertEqual(reloadedVideo.pixelWidth, video.pixelWidth)
        XCTAssertEqual(reloadedVideo.pixelHeight, video.pixelHeight)
        XCTAssertEqual(reloadedVideo.duration, video.duration)
        XCTAssertEqual(
            reloadedVideo.videoFilenamePrefixMatched,
            video.videoFilenamePrefixMatched
        )
        XCTAssertEqual(reloadedVideo.resolutionMatched, video.resolutionMatched)
        XCTAssertEqual(reloadedVideo.creationDate, video.creationDate)
        let reloadedPhoto = try XCTUnwrap(reloaded["photo-b/L0/001"])
        XCTAssertNil(reloadedPhoto.modificationDate)
        XCTAssertNil(reloadedPhoto.creationDate)
        XCTAssertTrue(reloadedPhoto.isUnresolved)

        // 文件内版本号改成 +1：整份作废，读回空缓存。
        let original = try String(contentsOf: store.fileURL, encoding: .utf8)
        let versionField = Self.quote + "cacheSchemaVersion" + Self.quote + ":"
        let currentVersion = versionField + String(S0ScanRules.cacheSchemaVersion)
        let bumpedVersion = versionField + String(S0ScanRules.cacheSchemaVersion + 1)
        XCTAssertEqual(original.components(separatedBy: currentVersion).count - 1, 1)
        try original.replacingOccurrences(of: currentVersion, with: bumpedVersion)
            .write(to: store.fileURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(store.load(), [:])

        // 正对照：版本号改回来即可再读出——空缓存确由版本不符造成，不是文件被写坏。
        try original.write(to: store.fileURL, atomically: true, encoding: .utf8)
        XCTAssertEqual(store.load(), entries)
    }

    // MARK: - 断言 5：续扫判定的四个集合（子项 B）

    func testIC153B_ResumeReusesUnchangedAndRefetchesChanged() {
        let base: TimeInterval = 780_000_000.5
        let library = [
            metadata("unchanged", created: base, modified: base),
            metadata("modified", created: base, modified: base + 60),
            metadata("new", created: base, modified: base),
            metadata("unresolved", created: base, modified: base),
            metadata("no-date-both", created: base, modified: nil),
            metadata("date-appeared", created: base, modified: base)
        ]
        let cache = [
            "unchanged": cacheEntry(modified: base),
            "modified": cacheEntry(modified: base),
            "gone": cacheEntry(modified: base),
            "unresolved": cacheEntry(modified: base, isUnresolved: true),
            "no-date-both": cacheEntry(modified: nil),
            "date-appeared": cacheEntry(modified: nil)
        ]
        let plan = S0ScanResumePlan.make(library: library, cache: cache)

        XCTAssertEqual(plan.reusedIDs, ["unchanged", "no-date-both"])
        XCTAssertEqual(plan.refetchIDs, ["modified", "new", "date-appeared"])
        XCTAssertEqual(plan.retryIDs, ["unresolved"])
        XCTAssertEqual(plan.discardedIDs, ["gone"])

        // 四个集合两两不相交，且前三个恰好覆盖库内全部资产。
        let covered = plan.reusedIDs.union(plan.refetchIDs).union(plan.retryIDs)
        XCTAssertEqual(covered, Set(library.map { $0.localIdentifier }))
        XCTAssertEqual(
            plan.reusedIDs.count + plan.refetchIDs.count + plan.retryIDs.count,
            library.count
        )
        XCTAssertTrue(covered.isDisjoint(with: plan.discardedIDs))

        // 空缓存：全部新增。
        let fresh = S0ScanResumePlan.make(library: library, cache: [:])
        XCTAssertEqual(fresh.refetchIDs, Set(library.map { $0.localIdentifier }))
        XCTAssertTrue(fresh.reusedIDs.isEmpty)
        XCTAssertTrue(fresh.retryIDs.isEmpty)
        XCTAssertTrue(fresh.discardedIDs.isEmpty)
    }

    // MARK: - 断言 6：中途取消后续扫不重取（子项 B）

    func testIC153B_CancelMidwayThenResumeDoesNotRefetch() throws {
        let library = sampleLibrary(count: 10)
        let fixture = ScanFixture(assets: library.assets, readings: library.readings)
        fixture.setBlockedAfterFetchCount(3)
        let directory = makeTemporaryDirectory()
        let service = S0LibraryScanService(
            source: fixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: directory)
        )

        service.advanceScan()
        XCTAssertTrue(
            waitUntil {
                service.currentSnapshot().progress.scannedAssetCount == 3
                    && fixture.fetchCount > 3
            },
            "没有停在第 3 项"
        )
        service.cancelScan()
        XCTAssertTrue(waitUntil { !service.isScanInFlight }, "取消后这一遍没有结束")

        // 取消后：仍有未处理条目 ⟹ 回报扫描中；已处理的三项已落盘。
        XCTAssertEqual(service.currentScanOutcome(), .scanning)
        XCTAssertEqual(
            service.currentSnapshot().progress,
            S0ScanProgress(scannedAssetCount: 3, totalAssetCount: 10)
        )
        let persisted = S0ScanCacheStore(directoryURL: directory).load()
        XCTAssertEqual(persisted.count, 3)
        let callsBeforeResume = fixture.fetchCount

        fixture.setBlockedAfterFetchCount(nil)
        service.advanceScan()
        XCTAssertTrue(
            waitUntil {
                !service.isScanInFlight && service.currentScanOutcome() == .completed
            },
            "续扫没有完成"
        )
        let resumedCalls = Array(fixture.fetchedIdentifiers.dropFirst(callsBeforeResume))
        XCTAssertEqual(resumedCalls.count, 10 - 3)
        XCTAssertTrue(Set(resumedCalls).isDisjoint(with: Set(persisted.keys)))

        // 与不中断跑一遍的结果相等。
        let referenceFixture = ScanFixture(assets: library.assets, readings: library.readings)
        let reference = S0LibraryScanService(
            source: referenceFixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: makeTemporaryDirectory())
        )
        reference.advanceScan()
        XCTAssertTrue(
            waitUntil {
                !reference.isScanInFlight && reference.currentScanOutcome() == .completed
            }
        )
        XCTAssertEqual(referenceFixture.fetchCount, 10)
        XCTAssertGreaterThan(reference.currentSnapshot().libraryTotalByteCount, 0)
        XCTAssertEqual(
            service.currentSnapshot().libraryTotalByteCount,
            reference.currentSnapshot().libraryTotalByteCount
        )
        XCTAssertEqual(service.currentSnapshot(), reference.currentSnapshot())
        XCTAssertEqual(S0ScanCacheStore(directoryURL: directory).load().count, 10)
    }

    // MARK: - 断言 7：完整缓存且无变更时不取字节（子项 B）

    func testIC153B_CompleteCacheWithoutChangesSkipsByteFetch() throws {
        let library = sampleLibrary(count: 12)
        let directory = makeTemporaryDirectory()

        let firstFixture = ScanFixture(assets: library.assets, readings: library.readings)
        let first = S0LibraryScanService(
            source: firstFixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: directory)
        )
        first.advanceScan()
        XCTAssertTrue(
            waitUntil { !first.isScanInFlight && first.currentScanOutcome() == .completed }
        )
        XCTAssertEqual(firstFixture.fetchCount, 12)
        let firstSnapshot = first.currentSnapshot()
        // 前置：三个类别都有项目、hero 非零，否则下面的「相等」会在空数据上空转。
        XCTAssertEqual(firstSnapshot.categories.map { $0.candidateCount > 0 }, [true, true, true])
        XCTAssertGreaterThan(firstSnapshot.cleanableByteCount, 0)

        // 新实例、同一缓存目录、同样的元数据。
        let secondFixture = ScanFixture(assets: library.assets, readings: library.readings)
        let second = S0LibraryScanService(
            source: secondFixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: directory)
        )
        second.advanceScan()
        XCTAssertTrue(
            waitUntil { !second.isScanInFlight && second.currentScanOutcome() == .completed }
        )
        XCTAssertEqual(secondFixture.fetchCount, 0, "完整缓存且无变更时发起了字节取数")
        XCTAssertEqual(secondFixture.enumerationCount, 1)
        XCTAssertEqual(second.currentScanOutcome(), .completed)
        XCTAssertEqual(second.currentSnapshot(), firstSnapshot)

        // 快照与缓存直接聚合的结果一致。
        let cached = S0ScanCacheStore(directoryURL: directory).load()
        XCTAssertEqual(cached.count, 12)
        let aggregated = S0ScanAggregator.snapshot(
            of: cached.map { $0.value.classified(id: $0.key) },
            context: S0ScanAggregationContext(
                progress: S0ScanProgress(scannedAssetCount: 12, totalAssetCount: 12),
                recognition: .settled,
                pendingDeletionAssetIDs: [],
                ledgerAssetIDs: [],
                ledgerEntries: [],
                isLimitedAuthorization: false
            )
        )
        XCTAssertEqual(second.currentSnapshot(), aggregated)

        // 再推进一遍仍不取字节（幂等）。
        second.advanceScan()
        XCTAssertTrue(waitUntil { !second.isScanInFlight })
        XCTAssertEqual(secondFixture.fetchCount, 0)
        XCTAssertEqual(secondFixture.enumerationCount, 2)
        XCTAssertEqual(second.currentScanOutcome(), .completed)
    }

    // MARK: - 断言 8：授权与读取的回报映射（子项 C）

    func testIC153C_ServiceOutcomeMapping() {
        let library = sampleLibrary(count: 8)

        // 未推进：不设「未开始」，回报扫描中；受限标志为假。
        let idleFixture = ScanFixture(assets: library.assets, readings: library.readings)
        let idle = makeService(idleFixture)
        XCTAssertEqual(idle.currentScanOutcome(), .scanning)
        XCTAssertFalse(idle.currentSnapshot().isLimitedAuthorization)

        // 不可读的授权（含未决定）：授权类失败、lim 为假，且不枚举、不取字节。
        let unreadable: [S1AuthorizationState] = [.denied, .restricted, .notDetermined, .unknown(99)]
        for authorization in unreadable {
            let fixture = ScanFixture(
                assets: library.assets,
                readings: library.readings,
                authorization: authorization
            )
            let service = makeService(fixture)
            service.advanceScan()
            XCTAssertTrue(waitUntil { !service.isScanInFlight })
            XCTAssertEqual(service.currentScanOutcome(), .failed(.authorization))
            XCTAssertFalse(service.currentSnapshot().isLimitedAuthorization)
            XCTAssertEqual(fixture.enumerationCount, 0)
            XCTAssertEqual(fixture.fetchCount, 0)
        }

        // 受限与完全授权：取字节挂起时回报扫描中、lim 分别为真与假；放行后转已完成。
        let readable: [(S1AuthorizationState, Bool)] = [(.limited, true), (.authorized, false)]
        for (authorization, expectedLimited) in readable {
            let fixture = ScanFixture(
                assets: library.assets,
                readings: library.readings,
                authorization: authorization
            )
            fixture.setBlockedAfterFetchCount(0)
            let service = makeService(fixture)
            service.advanceScan()
            XCTAssertTrue(waitUntil { fixture.fetchCount > 0 })
            XCTAssertEqual(service.currentScanOutcome(), .scanning)
            XCTAssertEqual(service.currentSnapshot().isLimitedAuthorization, expectedLimited)
            XCTAssertEqual(service.currentSnapshot().progress.totalAssetCount, 8)
            XCTAssertEqual(
                service.currentSnapshot().categories.map { $0.recognition },
                [.counting, .counting, .counting]
            )

            fixture.setBlockedAfterFetchCount(nil)
            XCTAssertTrue(waitUntil { !service.isScanInFlight })
            XCTAssertEqual(service.currentScanOutcome(), .completed)
            XCTAssertEqual(service.currentSnapshot().isLimitedAuthorization, expectedLimited)
            XCTAssertEqual(
                service.currentSnapshot().categories.map { $0.recognition },
                [.settled, .settled, .settled]
            )
        }

        // 枚举抛错：读取类失败。
        let failingFixture = ScanFixture(assets: library.assets, readings: library.readings)
        failingFixture.setEnumerationThrows(true)
        let failing = makeService(failingFixture)
        failing.advanceScan()
        XCTAssertTrue(waitUntil { !failing.isScanInFlight })
        XCTAssertEqual(failing.currentScanOutcome(), .failed(.read))
        XCTAssertEqual(failingFixture.fetchCount, 0)

        // 授权变化后再推进即续扫（服务不自己弹系统授权窗）。
        let grantingFixture = ScanFixture(
            assets: library.assets,
            readings: library.readings,
            authorization: .notDetermined
        )
        let granting = makeService(grantingFixture)
        granting.advanceScan()
        XCTAssertTrue(waitUntil { !granting.isScanInFlight })
        XCTAssertEqual(granting.currentScanOutcome(), .failed(.authorization))
        grantingFixture.setAuthorization(.authorized)
        granting.advanceScan()
        XCTAssertTrue(
            waitUntil { !granting.isScanInFlight && granting.currentScanOutcome() == .completed }
        )
        XCTAssertEqual(grantingFixture.fetchCount, 8)
    }

    // MARK: - 断言 9：回调节流，但完成与失败那一次必达（子项 C）

    func testIC153C_SnapshotCallbackIsThrottledButTerminalIsDelivered() {
        let probe = S0SnapshotChangeThrottle(
            maximumDeliveriesPerSecond: S0ScanRules.snapshotThrottleHz,
            deliver: {}
        )
        let interval = probe.minimumIntervalNanoseconds
        XCTAssertEqual(interval, 250_000_000)

        // 50 条资产、每次取字节 20 ms：扫描持续数百毫秒，节流窗口里挤着多次进度。
        let library = sampleLibrary(count: 50)
        let fixture = ScanFixture(assets: library.assets, readings: library.readings)
        fixture.setFetchDelay(nanoseconds: 20_000_000)
        let service = makeService(fixture)
        let log = CallbackLog()
        service.onSnapshotDidChange = { [weak service] in
            // 先取时刻、再做与 App 接线同量级的取数。
            let uptime = DispatchTime.now().uptimeNanoseconds
            let outcome = service?.currentScanOutcome()
            _ = service?.currentSnapshot()
            log.record(uptime: uptime, outcome: outcome, onMainThread: Thread.isMainThread)
        }
        service.advanceScan()
        XCTAssertTrue(
            waitUntil(timeout: 20) {
                !service.isScanInFlight && log.lastOutcome == .completed
            },
            "完成那一次回调没有送达"
        )
        // 再等两个节流间隔：之后不得有迟到的回调改写结论。
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))

        XCTAssertGreaterThanOrEqual(log.uptimes.count, 2)
        XCTAssertEqual(log.mainThreadFlags, Array(repeating: true, count: log.uptimes.count))
        for index in log.uptimes.indices.dropFirst() {
            XCTAssertGreaterThanOrEqual(
                log.uptimes[index] - log.uptimes[index - 1],
                interval,
                "两次回调的间隔短于节流间隔"
            )
        }
        XCTAssertEqual(log.lastOutcome, .completed)
        XCTAssertEqual(service.currentScanOutcome(), .completed)
        XCTAssertEqual(
            service.currentSnapshot().progress,
            S0ScanProgress(scannedAssetCount: 50, totalAssetCount: 50)
        )

        // 失败夹具：最后一次回调后回报失败。
        let failingFixture = ScanFixture(assets: library.assets, readings: library.readings)
        failingFixture.setEnumerationThrows(true)
        let failing = makeService(failingFixture)
        let failureLog = CallbackLog()
        failing.onSnapshotDidChange = { [weak failing] in
            let uptime = DispatchTime.now().uptimeNanoseconds
            let outcome = failing?.currentScanOutcome()
            failureLog.record(uptime: uptime, outcome: outcome, onMainThread: Thread.isMainThread)
        }
        failing.advanceScan()
        XCTAssertTrue(
            waitUntil {
                !failing.isScanInFlight && failureLog.lastOutcome == .failed(.read)
            },
            "失败那一次回调没有送达"
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        XCTAssertGreaterThanOrEqual(failureLog.uptimes.count, 1)
        XCTAssertEqual(failureLog.lastOutcome, .failed(.read))
        XCTAssertEqual(
            failureLog.mainThreadFlags,
            Array(repeating: true, count: failureLog.uptimes.count)
        )
    }

    // MARK: - 断言 10：主线程零源调用；不推进就不动（子项 C）

    func testIC153C_NoPhotoKitOnMainThreadAndIdleUntilAdvance() {
        let library = sampleLibrary(count: 9)
        let fixture = ScanFixture(assets: library.assets, readings: library.readings)
        let directory = makeTemporaryDirectory()
        let store = S0ScanCacheStore(directoryURL: directory)
        let service = S0LibraryScanService(source: fixture.makeSource(), cacheStore: store)
        var callbackCount = 0
        service.onSnapshotDidChange = {
            callbackCount += 1
        }

        // 构造后不推进：读两个回报也不触发任何源调用，缓存文件（连目录）都不存在。
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(service.currentScanOutcome(), .scanning)
        XCTAssertEqual(service.currentSnapshot().progress, S0ScanProgress())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        XCTAssertEqual(fixture.totalCallCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
        XCTAssertEqual(callbackCount, 0)

        // 推进：取字节挂起时再推进一次，无副作用（幂等）。
        fixture.setBlockedAfterFetchCount(0)
        service.advanceScan()
        XCTAssertTrue(waitUntil { fixture.fetchCount > 0 })
        service.advanceScan()
        fixture.setBlockedAfterFetchCount(nil)
        XCTAssertTrue(
            waitUntil { !service.isScanInFlight && service.currentScanOutcome() == .completed }
        )
        XCTAssertEqual(fixture.authorizationReadCount, 1)
        XCTAssertEqual(fixture.enumerationCount, 1)
        XCTAssertEqual(fixture.fetchCount, 9)
        XCTAssertEqual(fixture.totalCallCount, 11)
        XCTAssertEqual(fixture.mainThreadCallCount, 0, "有源调用落在主线程上")
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.fileURL.path))
        XCTAssertTrue(waitUntil { callbackCount > 0 })

        // 取字节的顺序：拍摄时间新的在前（样本库拍摄时间随序号递增）。
        let metadataByID = Dictionary(
            uniqueKeysWithValues: library.assets.map { ($0.localIdentifier, $0) }
        )
        XCTAssertEqual(
            S0LibraryScanService.newestFirst(Set(metadataByID.keys), metadataByID: metadataByID),
            Array(library.assets.map { $0.localIdentifier }.reversed())
        )
    }

    // MARK: - 断言 11：App 接线，S0View 只加协议属性（子项 C）

    func testIC153C_AppWiringAndS0ViewUntouched() throws {
        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "S0CleanupDataStub(", in: app), 0)
        XCTAssertGreaterThanOrEqual(occurrences(of: "S0LibraryScanService(", in: app), 1)
        XCTAssertEqual(occurrences(of: "advanceScan()", in: app), 2)
        XCTAssertGreaterThanOrEqual(occurrences(of: "allPendingDeletionAssetIDs", in: app), 1)
        XCTAssertEqual(occurrences(of: "onSnapshotDidChange", in: app), 1)
        XCTAssertEqual(occurrences(of: "S0ScanOutcomeTransition.events(", in: app), 1)

        let view = try XCTUnwrap(strippedSource(Self.s0ViewPath))
        XCTAssertEqual(occurrences(of: "machine.handle(", in: view), 4)
        XCTAssertEqual(occurrences(of: "machine.ingest", in: view), 1)
        XCTAssertEqual(occurrences(of: "onSnapshotDidChange", in: view), 1)
        XCTAssertEqual(
            occurrences(of: "var onSnapshotDidChange: (() -> Void)? { get set }", in: view),
            1
        )
        XCTAssertEqual(occurrences(of: "PHAsset", in: view), 0)

        // 迁移映射：每个（起点，回报）组合把给出的事件喂给真实状态机，`SC` 落到回报
        // 对应的值；起点与回报一致时不给事件。
        let outcomes: [S0ScanOutcome] = [
            .scanning,
            .completed,
            .failed(.authorization),
            .failed(.read)
        ]
        for start in outcomes {
            for outcome in outcomes {
                let machine = machineSettled(at: start)
                let events = S0ScanOutcomeTransition.events(
                    for: outcome,
                    scanState: machine.scanState,
                    failureCategory: machine.failureCategory
                )
                for event in events {
                    machine.handle(event)
                }
                XCTAssertEqual(machine.scanState, expectedScanState(for: outcome))
                XCTAssertEqual(machine.failureCategory, expectedFailureCategory(for: outcome))
                XCTAssertEqual(events.isEmpty, start == outcome)
            }
        }

        // 扫描中的进度不发迁移。
        XCTAssertEqual(
            S0ScanOutcomeTransition.events(
                for: .scanning,
                scanState: .scanning,
                failureCategory: nil
            ),
            []
        )
        // 从失败直接到已完成：先过扫描中，重排恰一次。
        let recovered = machineSettled(at: .failed(.authorization))
        let reorderBefore = recovered.categoryReorderCount
        for event in S0ScanOutcomeTransition.events(
            for: .completed,
            scanState: recovered.scanState,
            failureCategory: recovered.failureCategory
        ) {
            recovered.handle(event)
        }
        XCTAssertEqual(recovered.categoryReorderCount - reorderBefore, 1)
        XCTAssertEqual(recovered.state, .empty)
    }

    // MARK: - 断言 12：取数选项不含隐藏与最近删除，私有 API 隔离（子项 C）

    func testIC153C_ProductionSourceFetchOptionsExcludeHiddenAndDeleted() throws {
        let service = try XCTUnwrap(strippedSource(Self.servicePath))
        XCTAssertEqual(occurrences(of: "includeHiddenAssets = true", in: service), 0)
        XCTAssertEqual(occurrences(of: "includeHiddenAssets", in: service), 0)
        XCTAssertEqual(occurrences(of: "smartAlbumAllHidden", in: service), 0)
        XCTAssertEqual(occurrences(of: "smartAlbumRecentlyDeleted", in: service), 0)
        XCTAssertEqual(occurrences(of: "fetchAssets(in:", in: service), 0)
        XCTAssertEqual(occurrences(of: "fetchAssetCollections", in: service), 0)
        XCTAssertGreaterThanOrEqual(occurrences(of: "isNetworkAccessAllowed = false", in: service), 1)
        XCTAssertEqual(occurrences(of: "isNetworkAccessAllowed = true", in: service), 0)
        XCTAssertEqual(occurrences(of: "value(forKey:", in: service), 0)
        // 正对照（针对 needle 本身）：取数调用确实在这个文件里，扫描不是空转。
        XCTAssertEqual(occurrences(of: "PHAsset.fetchAssets(with: nil)", in: service), 1)
        XCTAssertEqual(occurrences(of: "PHAssetResource.assetResources(for:", in: service), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "originalFilename", in: service), 1)
        XCTAssertGreaterThan(occurrences(of: "import Photos", in: service), 0)

        // IC-145 断言 5 的私有 API 隔离口径：本卡新增与改动的产品文件一处都不用 KVC 取值、
        // 不出现那个非公开的资源属性键。
        let fileSizeKey = Self.quote + "fileSize" + Self.quote
        for relativePath in [
            Self.rulesPath,
            Self.classifierPath,
            Self.cachePath,
            Self.servicePath,
            Self.scannerPath,
            Self.appPath
        ] {
            let stripped = try XCTUnwrap(strippedSource(relativePath))
            XCTAssertGreaterThan(stripped.count, 0)
            XCTAssertEqual(occurrences(of: "value(forKey:", in: stripped), 0, relativePath)
            let raw = try XCTUnwrap(sourceText(relativePath))
            XCTAssertEqual(occurrences(of: fileSizeKey, in: raw), 0, relativePath)
        }

        // 取字节入口：新增的那一个接受调用方给的资源与选项；原入口仍在（未被改写成新入口）。
        let scanner = try XCTUnwrap(strippedSource(Self.scannerPath))
        XCTAssertEqual(
            occurrences(of: "func scan(_ asset: PHAsset) async -> AssetScanConclusion", in: scanner),
            1
        )
        XCTAssertEqual(occurrences(of: "options: PHAssetResourceRequestOptions", in: scanner), 2)
    }

    // MARK: - 断言 13：桩满足新协议且从不调钩子（子项 D）

    func testIC153D_StubConformsAndNeverFiresHook() {
        for scenario in S0CleanupDataStubScenario.allCases {
            let stub = S0CleanupDataStub(
                scenario: scenario,
                includesLedgerEntry: true,
                pendingDeletionByteCount: 1_000
            )
            var hookCount = 0
            stub.onSnapshotDidChange = {
                hookCount += 1
            }
            // 经协议看得见钩子（桩确实满足加了属性要求的协议）。
            let provider: any S0CleanupDataProviding = stub
            XCTAssertNotNil(provider.onSnapshotDidChange)

            // 走完全程并多推一步：每步都取两个回报。
            for _ in 0...S0CleanupDataStub.scanStepCount {
                _ = provider.currentSnapshot()
                _ = provider.currentScanOutcome()
                provider.advanceScan()
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            XCTAssertEqual(hookCount, 0, scenario.rawValue + " 的桩调用了快照钩子")

            // IC-147 断言 12 的确定性口径不变：同一台连取相等，同参数两台逐字段相等。
            let twin = S0CleanupDataStub(
                scenario: scenario,
                includesLedgerEntry: true,
                pendingDeletionByteCount: 1_000
            )
            for _ in 0...S0CleanupDataStub.scanStepCount {
                twin.advanceScan()
            }
            XCTAssertEqual(stub.currentSnapshot(), stub.currentSnapshot())
            XCTAssertEqual(stub.currentScanOutcome(), stub.currentScanOutcome())
            XCTAssertEqual(stub.scanStep, twin.scanStep)
            XCTAssertEqual(stub.currentSnapshot(), twin.currentSnapshot())
        }

        // 推进中逐步确定、走到头不再变化（同 IC-147 断言 12 第二段）。
        let first = S0CleanupDataStub(scenario: .scanning)
        let second = S0CleanupDataStub(scenario: .scanning)
        for _ in 0..<S0CleanupDataStub.scanStepCount {
            first.advanceScan()
            second.advanceScan()
            XCTAssertEqual(first.scanStep, second.scanStep)
            XCTAssertEqual(first.currentSnapshot(), second.currentSnapshot())
        }
        first.advanceScan()
        XCTAssertEqual(first.scanStep, S0CleanupDataStub.scanStepCount)
        XCTAssertEqual(first.currentScanOutcome(), .completed)
        // 桩的剧本不动：就绪剧本仍给五个类别（真实服务只给三个，裁定 二）。
        XCTAssertEqual(
            S0CleanupDataStub(scenario: .readyWithItems).currentSnapshot().categories.count,
            5
        )
    }

    // MARK: - 夹具

    private func assertClassification(
        _ asset: S0ScannedAsset,
        hits expectedHits: Set<S0CategoryIdentifier>,
        primary expectedPrimary: S0CategoryIdentifier?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let hits = S0ScanClassifier.hits(for: asset)
        XCTAssertEqual(
            hits,
            expectedHits,
            asset.id + " 的命中集合不符",
            file: file,
            line: line
        )
        XCTAssertEqual(
            S0ScanClassifier.primaryCategory(for: hits),
            expectedPrimary,
            asset.id + " 的去重归属不符",
            file: file,
            line: line
        )
        XCTAssertEqual(
            S0ScanClassifier.classified(asset).hits,
            expectedHits,
            asset.id + " 的分类结果与命中集合不一致",
            file: file,
            line: line
        )
    }

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

    private func metadata(
        _ id: String,
        mediaType: S0ScannedMediaType = .photo,
        isScreenshot: Bool = false,
        pixelWidth: Int = 4_032,
        pixelHeight: Int = 3_024,
        created: TimeInterval,
        modified: TimeInterval?
    ) -> S0AssetMetadata {
        S0AssetMetadata(
            localIdentifier: id,
            modificationDate: modified.map { Date(timeIntervalSinceReferenceDate: $0) },
            creationDate: Date(timeIntervalSinceReferenceDate: created),
            mediaType: mediaType,
            isScreenshot: isScreenshot,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            duration: mediaType == .video ? 30 : 0
        )
    }

    private func cacheEntry(
        modified: TimeInterval?,
        isUnresolved: Bool = false
    ) -> S0ScanCacheEntry {
        S0ScanCacheEntry(
            modificationDate: modified.map { Date(timeIntervalSinceReferenceDate: $0) },
            byteCount: isUnresolved ? 0 : 3_000_000,
            isUnresolved: isUnresolved,
            mediaType: .photo,
            isScreenshot: false,
            pixelWidth: 4_032,
            pixelHeight: 3_024,
            duration: 0,
            videoFilenamePrefixMatched: false,
            resolutionMatched: false,
            creationDate: nil
        )
    }

    /// 样本库：每四条一轮——大视频、截图、小录屏（前缀命中）、普通照片。
    /// 拍摄时间逐条递增一分钟，修改时间比拍摄晚 0.25 秒（带小数秒）。
    private func sampleLibrary(
        count: Int
    ) -> (assets: [S0AssetMetadata], readings: [String: FixtureReading]) {
        let megabyte: Int64 = 1_000_000
        var assets: [S0AssetMetadata] = []
        var readings: [String: FixtureReading] = [:]
        for index in 0..<count {
            let identifier = "asset-" + String(index) + "/L0/001"
            let created = 780_000_000 + TimeInterval(index * 60)
            let modified = created + 0.25
            switch index % 4 {
            case 0:
                assets.append(
                    metadata(
                        identifier,
                        mediaType: .video,
                        pixelWidth: 3_840,
                        pixelHeight: 2_160,
                        created: created,
                        modified: modified
                    )
                )
                readings[identifier] = FixtureReading(
                    videoFilename: "IMG_" + String(index) + ".MOV",
                    byteCount: (120 + Int64(index)) * megabyte
                )
            case 1:
                assets.append(
                    metadata(
                        identifier,
                        isScreenshot: true,
                        pixelWidth: 1_206,
                        pixelHeight: 2_622,
                        created: created,
                        modified: modified
                    )
                )
                readings[identifier] = FixtureReading(
                    videoFilename: nil,
                    byteCount: 2 * megabyte
                )
            case 2:
                assets.append(
                    metadata(
                        identifier,
                        mediaType: .video,
                        pixelWidth: 886,
                        pixelHeight: 1_920,
                        created: created,
                        modified: modified
                    )
                )
                readings[identifier] = FixtureReading(
                    videoFilename: "ScreenRecording_" + String(index) + ".mp4",
                    byteCount: 20 * megabyte
                )
            default:
                assets.append(
                    metadata(identifier, created: created, modified: modified)
                )
                readings[identifier] = FixtureReading(
                    videoFilename: nil,
                    byteCount: 3 * megabyte
                )
            }
        }
        return (assets, readings)
    }

    private func makeService(_ fixture: ScanFixture) -> S0LibraryScanService {
        S0LibraryScanService(
            source: fixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: makeTemporaryDirectory())
        )
    }

    /// 让一台新状态机的 `SC` 落到与某个回报一致的值。
    private func machineSettled(at outcome: S0ScanOutcome) -> S0StateMachine {
        let machine = S0StateMachine()
        switch outcome {
        case .scanning:
            machine.handle(.applicationOpened)
        case .completed:
            machine.handle(.scanCompleted)
        case let .failed(category):
            machine.handle(.scanFailed(category))
        }
        return machine
    }

    private func expectedScanState(for outcome: S0ScanOutcome) -> S0ScanState {
        switch outcome {
        case .scanning:
            return .scanning
        case .completed:
            return .completed
        case .failed:
            return .failed
        }
    }

    private func expectedFailureCategory(for outcome: S0ScanOutcome) -> S0FailureCategory? {
        if case let .failed(category) = outcome {
            return category
        }
        return nil
    }

    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
        super.tearDown()
    }

    /// 只给出路径、不建目录：缓存仓库第一次写入时才建（C4）。
    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IC153-" + UUID().uuidString, isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    /// 转主线程 run loop 直到条件成立或超时。服务的回调经主队列送达，
    /// 测试方法本身在主线程上，必须让 run loop 转起来才收得到。
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

    private static let fixtureDate = Date(timeIntervalSinceReferenceDate: 780_000_000.25)
    private static let rulesPath = "PhotoCleanupMVE/Services/S0ScanRules.swift"
    private static let classifierPath = "PhotoCleanupMVE/Services/S0ScanClassifier.swift"
    private static let cachePath = "PhotoCleanupMVE/Services/S0ScanCache.swift"
    private static let servicePath = "PhotoCleanupMVE/Services/S0LibraryScanService.swift"
    private static let scannerPath = "PhotoCleanupMVE/Services/AssetSizeScanner.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    private static let s0ViewPath = "PhotoCleanupMVE/Features/S0/S0View.swift"
    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    /// 双引号同理。
    private static let quote = String(Character(UnicodeScalar(UInt8(34))))

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148 一致）

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

    /// 取出源码里所有**独立的**数值字面量（与 IC-148 断言 3 同口径）。
    private func numericLiterals(in source: String) -> Set<String> {
        var literals: Set<String> = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            let previous = index > 0 ? characters[index - 1] : " "
            if isIdentifierCharacter(previous) {
                // 跳过整个标识符——判据必须含数字，否则指针不前进、循环不终止。
                while index < characters.count,
                      isIdentifierBodyCharacter(characters[index]) {
                    index += 1
                }
                continue
            }
            var end = index
            while end < characters.count,
                  characters[end].isNumber
                      || characters[end] == "."
                      || characters[end] == "_" {
                end += 1
            }
            if end < characters.count, characters[end].isLetter {
                index = end
                continue
            }
            var token = String(characters[index..<end])
            while token.hasSuffix(".") {
                token.removeLast()
            }
            token = token.replacingOccurrences(of: "_", with: "")
            if previous == "-" {
                token = "-" + token
            }
            if !token.isEmpty {
                literals.insert(token)
            }
            index = end
        }
        return literals
    }

    private func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    private func isIdentifierBodyCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
    }
}

/// 夹具读数：一次资源枚举给出的文件名与字节（字节为 nil 即取不到）。
private struct FixtureReading {
    let videoFilename: String?
    let byteCount: Int64?
}

private struct FixtureEnumerationError: Error {}

/// 回调记录。回调在主线程上送达，测试也在主线程上读，不另加锁。
private final class CallbackLog {
    private(set) var uptimes: [UInt64] = []
    private(set) var outcomes: [S0ScanOutcome?] = []
    private(set) var mainThreadFlags: [Bool] = []

    var lastOutcome: S0ScanOutcome? {
        outcomes.last ?? nil
    }

    func record(uptime: UInt64, outcome: S0ScanOutcome?, onMainThread: Bool) {
        uptimes.append(uptime)
        outcomes.append(outcome)
        mainThreadFlags.append(onMainThread)
    }
}

/// 夹具源。记下三个闭包各被调了几次、在哪条线程上；能让取字节延时，或在第 N 次
/// 之后挂起直到被取消或放行。
private final class ScanFixture {
    private struct Admission {
        let ordinal: Int
        let delayNanoseconds: UInt64
    }

    private let lock = NSLock()
    private var authorization: S1AuthorizationState
    private var assets: [S0AssetMetadata]
    private var readings: [String: FixtureReading]
    private var enumerationThrows = false
    private var fetchDelayNanoseconds: UInt64 = 0
    private var blockedAfterFetchCount: Int?
    private var fetched: [String] = []
    private var enumerations = 0
    private var authorizationReads = 0
    private var mainThreadFlags: [Bool] = []

    init(
        assets: [S0AssetMetadata],
        readings: [String: FixtureReading],
        authorization: S1AuthorizationState = .authorized
    ) {
        self.assets = assets
        self.readings = readings
        self.authorization = authorization
    }

    // MARK: 配置

    func setAuthorization(_ value: S1AuthorizationState) {
        locked { () -> Void in
            authorization = value
        }
    }

    func setEnumerationThrows(_ value: Bool) {
        locked { () -> Void in
            enumerationThrows = value
        }
    }

    func setFetchDelay(nanoseconds: UInt64) {
        locked { () -> Void in
            fetchDelayNanoseconds = nanoseconds
        }
    }

    func setBlockedAfterFetchCount(_ value: Int?) {
        locked { () -> Void in
            blockedAfterFetchCount = value
        }
    }

    // MARK: 读数

    var fetchCount: Int {
        locked { fetched.count }
    }

    var fetchedIdentifiers: [String] {
        locked { fetched }
    }

    var enumerationCount: Int {
        locked { enumerations }
    }

    var authorizationReadCount: Int {
        locked { authorizationReads }
    }

    var totalCallCount: Int {
        locked { mainThreadFlags.count }
    }

    var mainThreadCallCount: Int {
        locked { mainThreadFlags.filter { $0 }.count }
    }

    // MARK: 源

    func makeSource() -> S0LibraryScanSource {
        S0LibraryScanSource(
            authorizationState: { [self] in
                self.readAuthorization()
            },
            enumerateAssets: { [self] in
                try self.enumerate()
            },
            fetchResourcesAndBytes: { [self] identifier in
                let admission = self.beginFetch(identifier)
                if admission.delayNanoseconds > 0 {
                    try? await Task.sleep(nanoseconds: admission.delayNanoseconds)
                }
                while !Task.isCancelled, self.isBlocked(admission) {
                    try? await Task.sleep(nanoseconds: 2_000_000)
                }
                let reading = self.reading(for: identifier)
                return (videoFilename: reading.videoFilename, byteCount: reading.byteCount)
            }
        )
    }

    private func readAuthorization() -> S1AuthorizationState {
        locked { () -> S1AuthorizationState in
            authorizationReads += 1
            mainThreadFlags.append(Thread.isMainThread)
            return authorization
        }
    }

    private func enumerate() throws -> [S0AssetMetadata] {
        let outcome = locked { () -> (shouldThrow: Bool, assets: [S0AssetMetadata]) in
            enumerations += 1
            mainThreadFlags.append(Thread.isMainThread)
            return (enumerationThrows, assets)
        }
        if outcome.shouldThrow {
            throw FixtureEnumerationError()
        }
        return outcome.assets
    }

    private func beginFetch(_ identifier: String) -> Admission {
        locked { () -> Admission in
            fetched.append(identifier)
            mainThreadFlags.append(Thread.isMainThread)
            return Admission(
                ordinal: fetched.count,
                delayNanoseconds: fetchDelayNanoseconds
            )
        }
    }

    private func isBlocked(_ admission: Admission) -> Bool {
        locked { () -> Bool in
            guard let limit = blockedAfterFetchCount else {
                return false
            }
            return admission.ordinal > limit
        }
    }

    private func reading(for identifier: String) -> FixtureReading {
        locked {
            readings[identifier] ?? FixtureReading(videoFilename: nil, byteCount: nil)
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try body()
    }
}
