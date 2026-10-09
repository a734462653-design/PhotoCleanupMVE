import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-188：S1 重设计批第二张（下）——S1 改用看过集合（SPEC-S1 v12 决策 44、第二节 `已看(r)`、`看过档`·迁移）。
/// 1 已看 = 看过集合 `W` ∩ 本范围，与排序、与 `K` 的最远位置无关；未注入时为空。
/// 2 从 S1 进入：当前 `O` 下第一张没看过的；全部看过从第一张开始；不读 `K`。
/// 3 迁移纯计算：范围标识所属维度、另读哪些维度（本次采用的维度不重读）、`p_范围` 前缀之并（虚拟范围、给不出序列、`p` 已失效都不算）。
/// 4 协调器：恢复的旧会话档在第一次采用范围时、`K` 钳制之前迁移一次，立即写盘、置标记；之后再采用不再迁移；
///   迁移后的进入位置跟着变。
/// 5 新会话没有可迁的内容：只置标记、不写盘。
/// 6 源码落位：两个注入口、迁移在钳制之前、进入位置不读 `K`；协调器的注入与迁移；测试隔离持久层。
///
/// **夹具驱动**：其它维度的同步读取在测试宿主里没有相册授权、读不到，按「跳过」处理（陷阱 1）。
final class IC188SeenSwitchTests: XCTestCase {
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let migrationPath = "PhotoCleanupMVE/Core/S1LegacyProgressMigration.swift"
    private static let libraryPath = "PhotoCleanupMVE/Services/PhotoLibraryService.swift"

    private let month9 = S1Range(id: "month:1:2026:9", displayName: "2026年9月", assetIDsNewestFirst: ["a4", "a3", "a2", "a1"])
    private let month8 = S1Range(id: "month:1:2026:8", displayName: "2026年8月", assetIDsNewestFirst: ["b3", "b2", "b1"])
    private let month7 = S1Range(id: "month:1:2026:7", displayName: "2026年7月", assetIDsNewestFirst: ["c2", "c1"])

    // MARK: - 断言 1：已看 = W ∩ A(r)

    func testIC188A_ProcessedIsSeenSetIntersection() throws {
        let machine = try makeReadyMachine(ranges: [month9, month8])
        XCTAssertEqual(machine.processedAssetIDs(for: month9.id), [])
        XCTAssertEqual(processedCounts(machine), [month9.id: 0, month8.id: 0])

        machine.seenAssetIDsProvider = { ["a1", "a3", "b2", "elsewhere"] }
        XCTAssertEqual(machine.processedAssetIDs(for: month9.id), ["a1", "a3"])
        XCTAssertEqual(processedCounts(machine), [month9.id: 2, month8.id: 1])
        XCTAssertEqual(machine.processedAssetIDs(for: "month:1:2026:1"), [])

        // 与排序无关。
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.processedAssetIDs(for: month9.id), ["a1", "a3"])
        XCTAssertEqual(processedCounts(machine), [month9.id: 2, month8.id: 1])
    }

    // MARK: - 断言 2：进入位置 = 第一张没看过的

    func testIC188B_EntryStartsAtFirstUnseenAndIgnoresK() throws {
        // `K` 里记着 a3 为上次位置——进入时不读它。
        var store = SessionStore(sessionID: "会话-188B")
        let returned = SessionStore.S2Return(
            sourceSessionID: "会话-188B",
            sourceRangeID: month9.id,
            pendingDeletionAssetIDs: [],
            currentAssetID: "a3",
            farthestAssetID: "a3"
        )
        XCTAssertTrue(
            store.applyS2Return(
                returned,
                entryContext: SessionStore.S2EntryContext(
                    rangeID: month9.id,
                    orderedAssetIDs: month9.assetIDsNewestFirst,
                    sortOrder: .newestFirst
                )
            )
        )
        let machine = try makeReadyMachine(ranges: [month9], store: store)
        XCTAssertEqual(machine.sessionStore.continuationsByRangeID[month9.id]?.currentAssetID, "a3")

        // 未注入看过集合：第一张。
        XCTAssertEqual(machine.makeS2Handoff(for: month9.id)?.currentAssetID, "a4")
        // 看过 a4、a3：从 a2 开始。
        machine.seenAssetIDsProvider = { ["a4", "a3"] }
        XCTAssertEqual(machine.makeS2Handoff(for: month9.id)?.currentAssetID, "a2")
        // 最旧在前：a1 没看过，从 a1 开始。
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.makeS2Handoff(for: month9.id)?.currentAssetID, "a1")
        // 全部看过：从当前 `O` 下的第一张开始。
        machine.seenAssetIDsProvider = { ["a1", "a2", "a3", "a4"] }
        XCTAssertEqual(machine.makeS2Handoff(for: month9.id)?.currentAssetID, "a1")
        XCTAssertTrue(machine.switchSortOrder(to: .newestFirst))
        XCTAssertEqual(machine.makeS2Handoff(for: month9.id)?.currentAssetID, "a4")
    }

    // MARK: - 断言 3：迁移纯计算

    func testIC188C_MigrationPureFunctions() throws {
        XCTAssertEqual(S1LegacyProgressMigration.virtualRangePrefix, S0CategoryPageRange.prefix)
        XCTAssertEqual(S1LegacyProgressMigration.dimension(ofRangeID: "year:1:2026:0"), .date)
        XCTAssertEqual(S1LegacyProgressMigration.dimension(ofRangeID: "month:1:2026:9"), .date)
        XCTAssertEqual(S1LegacyProgressMigration.dimension(ofRangeID: "s1-unclassified"), .unclassified)
        XCTAssertEqual(S1LegacyProgressMigration.dimension(ofRangeID: "album-x"), .album)
        XCTAssertNil(S1LegacyProgressMigration.dimension(ofRangeID: "cat:video"))

        let legacy = legacyProgress()
        // 本次采用日期维度：只另读相册——`K` 里同维度已消失的 3 月不触发重读；采用相册时另读日期；未分类时两个都读。
        XCTAssertEqual(
            S1LegacyProgressMigration.dimensionsToRead(for: legacy, adoptedDimension: .date),
            [.album]
        )
        XCTAssertEqual(
            S1LegacyProgressMigration.dimensionsToRead(for: legacy, adoptedDimension: .album),
            [.date]
        )
        XCTAssertEqual(
            S1LegacyProgressMigration.dimensionsToRead(for: legacy, adoptedDimension: .unclassified),
            [.date, .album]
        )
        // 最新在前记的 a3 → {a4, a3}；最旧在前记的 b2 → {b1, b2}；`p` 已失效的 7 月、虚拟范围、给不出序列的相册都不算。
        let sequences = [
            month9.id: month9.assetIDsNewestFirst,
            month8.id: month8.assetIDsNewestFirst,
            month7.id: month7.assetIDsNewestFirst
        ]
        XCTAssertEqual(
            S1LegacyProgressMigration.migratedAssetIDs(from: legacy, sequencesNewestFirst: sequences),
            ["a4", "a3", "b1", "b2"]
        )
        XCTAssertEqual(
            S1LegacyProgressMigration.migratedAssetIDs(from: legacy, sequencesNewestFirst: [:]),
            []
        )
    }

    // MARK: - 断言 4：协调器在钳制之前迁移一次

    @MainActor
    func testIC188D_CoordinatorMigratesOnceBeforeClamp() throws {
        let persistence = TestPersistenceIsolation.makePersistence()
        let legacy = legacyProgress()
        let snapshot = S1SessionSnapshot(
            sessionID: "会话-188D",
            groupingDimension: .date,
            sortOrder: .newestFirst,
            pendingDeletionAssetIDsByRangeID: [:],
            continuationsByRangeID: legacy.mapValues { SessionStore.Continuation(currentAssetID: $0.farthestAssetID) },
            firstMarkedRangeIDByAssetID: [:],
            legacyProgressByRangeID: legacy
        )
        let coordinator = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1(restoring: snapshot))
        XCTAssertFalse(coordinator.currentSeenArchive().hasMigratedLegacyProgress)

        // 第一次采用日期维度：迁移在 `K` 钳制之前——7 月的 `p` 已失效、不算看过；3 月整月已不在、不触发重读日期维度；相册维度在宿主里读不到、跳过。
        completeRead(coordinator, ranges: [month9, month8, month7])
        let archive = coordinator.currentSeenArchive()
        XCTAssertTrue(archive.hasMigratedLegacyProgress)
        XCTAssertEqual(archive.seenAssetIDs, ["a4", "a3", "b1", "b2"])
        XCTAssertEqual(persistence.loadS1SeenArchive(), archive)

        // 迁移后的进入位置：9 月从 a2 开始，8 月（最新在前）从 b3 开始。
        let machine = try XCTUnwrap(coordinator.s1Machine)
        XCTAssertEqual(machine.makeS2Handoff(for: month9.id)?.currentAssetID, "a2")
        XCTAssertEqual(machine.makeS2Handoff(for: month8.id)?.currentAssetID, "b3")
        XCTAssertEqual(machine.processedAssetIDs(for: month7.id), [])

        // 之后再采用（切到相册维度、读到那本相册）：不再迁移。
        XCTAssertTrue(machine.switchGroupingDimension(to: .album))
        let album = S1Range(id: "album-x", displayName: "相册", assetIDsNewestFirst: ["x2", "x1"])
        completeRead(coordinator, ranges: [album])
        XCTAssertEqual(coordinator.currentSeenArchive(), archive)
        XCTAssertEqual(machine.makeS2Handoff(for: album.id)?.currentAssetID, "x2")
    }

    // MARK: - 断言 5：新会话没有可迁的内容

    @MainActor
    func testIC188E_EmptyLegacyStoreSetsFlagWithoutWriting() throws {
        let persistence = TestPersistenceIsolation.makePersistence()
        let coordinator = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-188E"))
        completeRead(coordinator, ranges: [month9])
        XCTAssertTrue(coordinator.currentSeenArchive().hasMigratedLegacyProgress)
        XCTAssertTrue(coordinator.currentSeenArchive().seenAssetIDs.isEmpty)
        XCTAssertNil(persistence.loadS1SeenArchive())
    }

    // MARK: - 断言 6：源码落位

    func testIC188F_SourceWiring() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        XCTAssertEqual(occurrences(of: "var seenAssetIDsProvider: (() -> Set<String>)?", in: machine), 1)
        XCTAssertEqual(occurrences(of: "var legacyProgressMigration: ((_ ranges: [S1Range], _ groupingDimension: S1GroupingDimension, _ legacyProgress: [String: S1LegacyProgress]) -> Void)?", in: machine), 1)
        // IC-189：「新增 N 张」的派生量也读看过集合（`newAssetCount(for:)`），2 → 3。
        XCTAssertEqual(occurrences(of: "seenAssetIDsProvider?() ?? []", in: machine), 3)
        XCTAssertEqual(occurrences(of: "legacyProgressMigration?(newRanges, groupingDimension, legacyProgressByRangeID)", in: machine), 1)
        let adopt = try XCTUnwrap(slice(machine, from: "private func adoptRanges(", to: "publishSnapshotIfChanged()"))
        let migrate = try XCTUnwrap(adopt.range(of: "legacyProgressMigration?(newRanges, groupingDimension, legacyProgressByRangeID)"))
        let clamp = try XCTUnwrap(adopt.range(of: "Self.reconciledStore(sessionStore, against: newRanges)"))
        XCTAssertLessThan(migrate.lowerBound, clamp.lowerBound)
        let handoff = try XCTUnwrap(slice(machine, from: "func makeS2Handoff(for rangeID: String) -> S1ToS2Handoff? {", to: "sessionMergedPendingDeletionCountProvider"))
        XCTAssertEqual(occurrences(of: "continuationsByRangeID", in: handoff), 0)
        XCTAssertEqual(occurrences(of: "seenAssetIDsProvider?() ?? []", in: handoff), 1)
        let processed = try XCTUnwrap(slice(machine, from: "func processedAssetIDs(for rangeID: String) -> Set<String> {", to: "func completeRangeRead("))
        XCTAssertEqual(occurrences(of: "sessionStore.processedAssetIDs(", in: processed), 0)
        // 既有钉子不变。
        XCTAssertEqual(occurrences(of: "publishSnapshotIfChanged()", in: machine), 6)
        XCTAssertEqual(occurrences(of: "didSet", in: machine), 4)
        XCTAssertEqual(occurrences(of: "setMarked(", in: machine), 3)

        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "machine.seenAssetIDsProvider = {", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "machine.legacyProgressMigration = {", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "private func migrateLegacyProgressIfNeeded(", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "migrateLegacyProgressIfNeeded(", in: coordinator), 2)
        XCTAssertEqual(occurrences(of: "readS1Ranges(groupedBy: dimension)", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "adoptedDimension: groupingDimension", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "archive.hasMigratedLegacyProgress = true", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "flushSeenArchive()", in: coordinator), 4)
        XCTAssertEqual(occurrences(of: "photoLibrary.s1RangeRead(", in: coordinator), 2)

        let migrationRaw = try XCTUnwrap(sourceText(Self.migrationPath))
        let migration = try XCTUnwrap(strippedSource(Self.migrationPath))
        XCTAssertEqual(occurrences(of: "import ", in: migrationRaw), 1)
        XCTAssertEqual(occurrences(of: "import Foundation", in: migrationRaw), 1)
        for needle in ["Photos", "PHAsset", "L10n.", "@MainActor", "S0"] {
            XCTAssertEqual(occurrences(of: needle, in: migration), 0, needle)
        }
        // 未分类范围标识与照片库读取处同值。
        let libraryRaw = try XCTUnwrap(sourceText(Self.libraryPath))
        let unclassifiedLiteral = Self.quote + S1LegacyProgressMigration.unclassifiedRangeID + Self.quote
        XCTAssertEqual(occurrences(of: unclassifiedLiteral, in: libraryRaw), 1)
    }

    // MARK: - 夹具

    /// 旧会话档带来的 v11 旧进度（IC-190 起不在 `K` 里）：9 月最新在前记到 a3、8 月最旧在前记到 b2、7 月记的资产已不在、
    /// 3 月整月已不在（给不出序列）、一本相册、一个虚拟范围。
    private func legacyProgress() -> [String: S1LegacyProgress] {
        [
            month9.id: S1LegacyProgress(farthestAssetID: "a3", recordedSortOrder: .newestFirst),
            month8.id: S1LegacyProgress(farthestAssetID: "b2", recordedSortOrder: .oldestFirst),
            month7.id: S1LegacyProgress(farthestAssetID: "gone", recordedSortOrder: .newestFirst),
            "month:1:2026:3": S1LegacyProgress(farthestAssetID: "m1", recordedSortOrder: .newestFirst),
            "album-x": S1LegacyProgress(farthestAssetID: "x1", recordedSortOrder: .newestFirst),
            "cat:video": S1LegacyProgress(farthestAssetID: "v1", recordedSortOrder: .newestFirst)
        ]
    }

    private func makeReadyMachine(
        ranges: [S1Range],
        store: SessionStore = SessionStore(sessionID: "会话-188")
    ) throws -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        let request = try XCTUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
        return machine
    }

    private func processedCounts(_ machine: S1StateMachine) -> [String: Int] {
        var counts: [String: Int] = [:]
        for row in machine.rangeRows {
            counts[row.id] = row.processedAssetCount
        }
        return counts
    }

    @MainActor
    private func completeRead(_ coordinator: CleanupCoordinator, ranges: [S1Range]) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
    }

    /// 双引号用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的教训）。
    private static let quote = String(Character(UnicodeScalar(UInt8(34))))

    // MARK: - 工具（与既有测试同口径）

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start),
              let endRange = text.range(of: end, range: startRange.upperBound..<text.endIndex) else {
            return nil
        }
        return String(text[startRange.lowerBound..<endRange.upperBound])
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
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}
