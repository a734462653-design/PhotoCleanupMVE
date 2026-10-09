import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-190：S1 重设计批第四张——退役 `p_范围`／`O_记录`／`farthestAssetID`、返回契约改本次看过集合、`K` 不钳制
/// （SPEC-S1 v12 第二节 `K`／`看过档`·迁移、`:74`；SPEC-S2 v24 第七节第 3 部分）。
/// 1 会话档：旧档两键同在 → 旧进度单独带出、`K` 只留 `c`；只有一个键、排序值非法、最远为空 → 坏档；
///   没有旧进度的快照写出时不带旧键，有旧进度时往返相等。
/// 2 状态机：旧进度从恢复带到第一次采用范围，交给迁移入口后清空；此前的快照带着它，此后不带。
/// 3 协调器：恢复旧档后、第一次采用范围之前写出的档（切排序、类别页进篮）仍带旧键；采用之后迁移照旧、写出的档不再带。
/// 4 返回契约：看过集合须是范围的子集，否则整份写回失败；写回只记 `c`；对账不钳 `K`。
/// 5 源码落位。
final class IC190LegacyRetirementTests: XCTestCase {
    private static let productRoot = "PhotoCleanupMVE"
    private static let storePath = "PhotoCleanupMVE/Core/SessionStore.swift"
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let s2Path = "PhotoCleanupMVE/Core/S2StateMachine.swift"
    private static let monthID = "month:1:2026:9"

    // MARK: - 断言 1：会话档分开带旧进度

    func testIC190A_ArchiveCarriesLegacyProgressSeparately() throws {
        let legacy = try decodedArchive([
            "currentAssetID": "b",
            "farthestAssetID": "a",
            "recordedSortOrder": "oldestFirst"
        ])
        let snapshot = try XCTUnwrap(legacy.snapshot)
        XCTAssertEqual(snapshot.continuationsByRangeID, ["r": SessionStore.Continuation(currentAssetID: "b")])
        XCTAssertEqual(
            snapshot.legacyProgressByRangeID,
            ["r": S1LegacyProgress(farthestAssetID: "a", recordedSortOrder: .oldestFirst)]
        )

        let fresh = try XCTUnwrap(try decodedArchive(["currentAssetID": "b"]).snapshot)
        XCTAssertEqual(fresh.continuationsByRangeID, ["r": SessionStore.Continuation(currentAssetID: "b")])
        XCTAssertEqual(fresh.legacyProgressByRangeID, [:])

        // 只有一个旧键、排序值非法、最远为空：坏档。
        let broken: [[String: String]] = [
            ["currentAssetID": "b", "farthestAssetID": "a"],
            ["currentAssetID": "b", "recordedSortOrder": "oldestFirst"],
            ["currentAssetID": "b", "farthestAssetID": "a", "recordedSortOrder": "sideways"],
            ["currentAssetID": "b", "farthestAssetID": "", "recordedSortOrder": "newestFirst"]
        ]
        for continuation in broken {
            XCTAssertNil(try decodedArchive(continuation).snapshot, continuation.description)
        }

        // 没有旧进度：写出不带两个旧键。有旧进度：往返相等。
        let freshData = try JSONEncoder().encode(PersistedS1Session(fresh))
        let freshText = String(decoding: freshData, as: UTF8.self)
        XCTAssertFalse(freshText.contains("farthestAssetID"))
        XCTAssertFalse(freshText.contains("recordedSortOrder"))
        let legacyData = try JSONEncoder().encode(PersistedS1Session(snapshot))
        let roundTrip = try JSONDecoder().decode(PersistedS1Session.self, from: legacyData)
        XCTAssertEqual(roundTrip.snapshot, snapshot)
    }

    // MARK: - 断言 2：状态机把旧进度交给迁移入口后清空

    func testIC190B_MachineCarriesLegacyUntilFirstAdopt() throws {
        let legacy = [Self.monthID: S1LegacyProgress(farthestAssetID: "a3", recordedSortOrder: .newestFirst)]
        let machine = try XCTUnwrap(S1StateMachine.restore(from: legacySnapshot(sessionID: "会话-190B", legacy: legacy)))
        var received: [[String: S1LegacyProgress]] = []
        machine.legacyProgressMigration = { _, _, progress in
            received.append(progress)
        }

        // 第一次采用范围之前：快照带着旧进度（此时写盘不丢迁移所需的数据）。
        XCTAssertEqual(machine.sessionSnapshot.legacyProgressByRangeID, legacy)
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(machine.sessionSnapshot.legacyProgressByRangeID, legacy)
        XCTAssertTrue(received.isEmpty)

        let month = S1Range(id: Self.monthID, displayName: "2026年9月", assetIDsNewestFirst: ["a4", "a3", "a2"])
        let request = try XCTUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success([month]), for: request))
        XCTAssertEqual(received, [legacy])
        XCTAssertEqual(machine.sessionSnapshot.legacyProgressByRangeID, [:])
        XCTAssertEqual(
            machine.sessionStore.continuationsByRangeID[Self.monthID],
            SessionStore.Continuation(currentAssetID: "a3")
        )

        // 之后再采用：迁移入口拿到空表。
        XCTAssertTrue(machine.reconcile(with: .success([month])))
        XCTAssertEqual(received, [legacy, [:]])
    }

    // MARK: - 断言 3：协调器——采用之前写出的档带旧键，采用之后不带

    @MainActor
    func testIC190C_PersistedArchiveDropsLegacyKeysAfterFirstAdopt() throws {
        let persistence = TestPersistenceIsolation.makePersistence()
        let legacy = [Self.monthID: S1LegacyProgress(farthestAssetID: "a3", recordedSortOrder: .newestFirst)]
        try persistence.saveS1Session(legacySnapshot(sessionID: "会话-190C", legacy: legacy))
        XCTAssertEqual(persistence.loadS1Session()?.legacyProgressByRangeID, legacy)

        let coordinator = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1ResumingPersistedSessionOrStartNew())
        let machine = try XCTUnwrap(coordinator.s1Machine)
        XCTAssertTrue(machine.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(persistence.loadS1Session()?.legacyProgressByRangeID, legacy)
        // 另一个迁移前的写盘入口（类别页进篮）：同一个快照出口，旧进度照样在档里。
        XCTAssertTrue(machine.markPendingDeletion(assetIDs: ["v1"], virtualRangeID: "cat:video", displayName: "视频"))
        XCTAssertEqual(persistence.loadS1Session()?.legacyProgressByRangeID, legacy)

        let month = S1Range(id: Self.monthID, displayName: "2026年9月", assetIDsNewestFirst: ["a4", "a3", "a2"])
        let request = try XCTUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success([month]), for: request))

        // 迁移照旧：最新在前记到 a3 → {a4, a3}，置标记；之后写出的档不再带旧进度、`K` 只留 `c`。
        XCTAssertEqual(coordinator.currentSeenArchive().seenAssetIDs, ["a4", "a3"])
        XCTAssertTrue(coordinator.currentSeenArchive().hasMigratedLegacyProgress)
        let saved = try XCTUnwrap(persistence.loadS1Session())
        XCTAssertEqual(saved.legacyProgressByRangeID, [:])
        XCTAssertEqual(saved.continuationsByRangeID, [Self.monthID: SessionStore.Continuation(currentAssetID: "a3")])
    }

    // MARK: - 断言 4：返回契约与对账

    func testIC190D_ReturnContractValidatesSeenSetAndKeepsOnlyCurrent() {
        var store = SessionStore(sessionID: "会话-190D")
        let context = SessionStore.S2EntryContext(
            rangeID: "r",
            orderedAssetIDs: ["a3", "a2", "a1"],
            sortOrder: .oldestFirst
        )
        let outside = SessionStore.S2Return(
            sourceSessionID: "会话-190D",
            sourceRangeID: "r",
            pendingDeletionAssetIDs: [],
            currentAssetID: "a2",
            seenAssetIDs: ["a2", "elsewhere"]
        )
        XCTAssertFalse(store.applyS2Return(outside, entryContext: context))
        XCTAssertNil(store.continuationsByRangeID["r"])

        let empty = SessionStore.S2Return(
            sourceSessionID: "会话-190D",
            sourceRangeID: "r",
            pendingDeletionAssetIDs: [],
            currentAssetID: "a2",
            seenAssetIDs: []
        )
        XCTAssertTrue(store.applyS2Return(empty, entryContext: context))
        XCTAssertEqual(store.continuationsByRangeID["r"], SessionStore.Continuation(currentAssetID: "a2"))

        // 对账不钳 `K`：a2 已不在序列里也不动、不算改动。
        XCTAssertFalse(store.reconcileRange("r", availableAssetIDsNewestFirst: ["a3"]))
        XCTAssertEqual(store.continuationsByRangeID["r"], SessionStore.Continuation(currentAssetID: "a2"))
    }

    // MARK: - 断言 5：源码落位

    func testIC190E_SourceWiring() throws {
        // 产品源码里 `farthestAssetID`／`recordedSortOrder` 只剩会话档（可选旧键）与迁移文件；`farthestIndex` 不再出现。
        let product = try productSources()
        XCTAssertFalse(product.isEmpty)
        XCTAssertEqual(
            product.filter { $0.value.contains("farthestAssetID") }.keys.sorted(),
            ["S1LegacyProgressMigration.swift", "SessionPersistence.swift"]
        )
        XCTAssertEqual(
            product.filter { $0.value.contains("recordedSortOrder") }.keys.sorted(),
            ["S1LegacyProgressMigration.swift", "SessionPersistence.swift"]
        )
        XCTAssertEqual(product.values.reduce(0) { $0 + occurrences(of: "farthestIndex", in: $1) }, 0)

        let store = try XCTUnwrap(strippedSource(Self.storePath))
        XCTAssertEqual(occurrences(of: "func processedAssetIDs(", in: store), 0)
        XCTAssertEqual(occurrences(of: "let seenAssetIDs: Set<AssetID>", in: store), 1)
        XCTAssertEqual(occurrences(of: "returned.seenAssetIDs.isSubset(of: assetIDSet)", in: store), 1)
        let continuation = try XCTUnwrap(slice(store, from: "struct Continuation: Equatable, Sendable {", to: "}"))
        XCTAssertEqual(occurrences(of: "let ", in: continuation), 1)
        let reconcile = try XCTUnwrap(slice(store, from: "mutating func reconcileRange(", to: "return state != before"))
        XCTAssertEqual(occurrences(of: "continuationsByRangeID", in: reconcile), 0)

        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        XCTAssertEqual(occurrences(of: "var legacyProgressMigration: ((_ ranges: [S1Range], _ groupingDimension: S1GroupingDimension, _ legacyProgress: [String: S1LegacyProgress]) -> Void)?", in: machine), 1)
        XCTAssertEqual(occurrences(of: "machine.legacyProgressByRangeID = snapshot.legacyProgressByRangeID", in: machine), 1)
        XCTAssertEqual(occurrences(of: "legacyProgressByRangeID = [:]", in: machine), 1)
        let adopt = try XCTUnwrap(slice(machine, from: "private func adoptRanges(", to: "publishSnapshotIfChanged()"))
        let handOver = try XCTUnwrap(adopt.range(of: "legacyProgressMigration?(newRanges, groupingDimension, legacyProgressByRangeID)"))
        let clear = try XCTUnwrap(adopt.range(of: "legacyProgressByRangeID = [:]"))
        XCTAssertLessThan(handOver.lowerBound, clear.lowerBound)
        // 既有钉子不变。
        XCTAssertEqual(occurrences(of: "publishSnapshotIfChanged()", in: machine), 6)
        XCTAssertEqual(occurrences(of: "didSet", in: machine), 4)
        XCTAssertEqual(occurrences(of: "setMarked(", in: machine), 3)
        // IC-191：页头已看（`headerSummary`）也读看过集合，3 → 4。
        XCTAssertEqual(occurrences(of: "seenAssetIDsProvider?() ?? []", in: machine), 4)

        let s2 = try XCTUnwrap(strippedSource(Self.s2Path))
        XCTAssertEqual(occurrences(of: "seenAssetIDs: visitSeenAssetIDs", in: s2), 1)

        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "recordSeenAssets(payload.upstreamReturn.seenAssetIDs)", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "recordSeenAssets(", in: coordinator), 4)
        XCTAssertEqual(occurrences(of: "from legacyProgress: [String: S1LegacyProgress]", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "flushSeenArchive()", in: coordinator), 4)
        XCTAssertEqual(occurrences(of: "photoLibrary.s1RangeRead(", in: coordinator), 2)
    }

    // MARK: - 夹具

    private func decodedArchive(_ continuation: [String: String]) throws -> PersistedS1Session {
        let object: [String: Any] = [
            "sessionID": "会话-190A",
            "groupingDimension": "album",
            "sortOrder": "newestFirst",
            "pendingDeletionAssetIDsByRangeID": [String: [String]](),
            "continuationsByRangeID": ["r": continuation],
            "firstMarkedRangeIDByAssetID": [String: String]()
        ]
        return try JSONDecoder().decode(
            PersistedS1Session.self,
            from: try JSONSerialization.data(withJSONObject: object)
        )
    }

    private func legacySnapshot(sessionID: String, legacy: [String: S1LegacyProgress]) -> S1SessionSnapshot {
        S1SessionSnapshot(
            sessionID: sessionID,
            groupingDimension: .date,
            sortOrder: .newestFirst,
            pendingDeletionAssetIDsByRangeID: [:],
            continuationsByRangeID: [Self.monthID: SessionStore.Continuation(currentAssetID: "a3")],
            firstMarkedRangeIDByAssetID: [:],
            legacyProgressByRangeID: legacy
        )
    }

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

    /// 产品目录下全部 `.swift`，按文件名剔注释与字符串内容（被查的文件名在产品目录里唯一）。
    private func productSources() throws -> [String: String] {
        let root = repoRoot().appendingPathComponent(Self.productRoot)
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else {
            return [:]
        }
        var result: [String: String] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            result[url.lastPathComponent] = stripped(source)
        }
        return result
    }

    private func strippedSource(_ relativePath: String) -> String? {
        sourceText(relativePath).map { stripped($0) }
    }

    /// 剔掉 `//` 注释与字符串字面量内容。
    private func stripped(_ source: String) -> String {
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
