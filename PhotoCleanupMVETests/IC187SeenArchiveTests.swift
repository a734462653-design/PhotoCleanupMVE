import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-187：S1 重设计批第二张（上）——看过档与「看过」的记录（SPEC-S1 v12 第二节 `W`、`t_离开`、`看过档`；
/// 决策 44、45；SPEC-S2 v24 第二节「看过」）。
/// 1 看过档持久化：往返逐位相等；不存在、不可解析、版本不符都读成 nil；清会话档不碰看过档。
/// 2 S2 只记停稳成为当前的那一张：进入时的第一张、上滑后自动进入的下一张、横栏拖完停住的那张、
///   翻页停稳的那张；横栏拖动途中经过的与翻页途中越过半页的不算；实时并入协调器、不立即写盘。
/// 3 协调器：写回成功才记 `t_离开`（虚拟范围也记）；写回失败不记离开时刻、实时记下的看过保留并写盘；
///   转入非活跃时写盘；换一个协调器（进程重启）读回同一份档。
/// 4 源码落位：记看过的汇集口、视图的停稳回调、协调器单一写出口、`finishSession()` 不碰看过档。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：翻页停稳由测试直接调 `notePagingSettled()`，真机由原生分页器的
/// `onPagingSettled` 经视图转来；「看过」的观感与已看进度归第二张（下）与 V1 视图卡的真机判定。
final class IC187SeenArchiveTests: XCTestCase {
    private static let machinePath = "PhotoCleanupMVE/Core/S2StateMachine.swift"
    private static let viewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let persistencePath = "PhotoCleanupMVE/Core/SessionPersistence.swift"
    private static let archivePath = "PhotoCleanupMVE/Core/S1SeenArchive.swift"

    private final class IsolatedFileManager: FileManager {
        private let applicationSupportRoot: URL

        init(applicationSupportRoot: URL) {
            self.applicationSupportRoot = applicationSupportRoot
            super.init()
        }

        override func urls(
            for directory: FileManager.SearchPathDirectory,
            in domainMask: FileManager.SearchPathDomainMask
        ) -> [URL] {
            if directory == .applicationSupportDirectory,
               domainMask.contains(.userDomainMask) {
                return [applicationSupportRoot]
            }
            return super.urls(for: directory, in: domainMask)
        }
    }

    private var temporaryRoots: [URL] = []

    override func tearDown() {
        for root in temporaryRoots {
            try? FileManager.default.removeItem(at: root)
        }
        temporaryRoots = []
        super.tearDown()
    }

    // MARK: - 断言 1：看过档持久化

    func testIC187A_ArchiveRoundTripAndCorruption() throws {
        let (persistence, directory) = makePersistence()
        XCTAssertNil(persistence.loadS1SeenArchive())

        let archive = S1SeenArchive(
            seenAssetIDs: ["资产-B", "资产-A"],
            leaveTimeByRangeID: [
                "范围-月": Date(timeIntervalSinceReferenceDate: 812_345_678.123_456),
                "cat:video": Date(timeIntervalSinceReferenceDate: 812_345_999.5)
            ],
            hasMigratedLegacyProgress: false
        )
        try persistence.saveS1SeenArchive(archive)
        XCTAssertEqual(persistence.loadS1SeenArchive(), archive)

        // 清会话档（S5 离开时的两步）不碰看过档。
        try persistence.clear()
        try persistence.clearS1Session()
        XCTAssertEqual(persistence.loadS1SeenArchive(), archive)

        let fileURL = directory.appendingPathComponent("s1-seen.json")
        // 坏档：不可解析。
        try Data([0x7B, 0x7D, 0x5D]).write(to: fileURL)
        XCTAssertNil(persistence.loadS1SeenArchive())
        // 坏档：版本不符。
        try archiveJSON(schemaVersion: 2, seenAssetIDs: []).write(to: fileURL)
        XCTAssertNil(persistence.loadS1SeenArchive())
        // 坏档：标识重复。
        try archiveJSON(schemaVersion: 1, seenAssetIDs: ["a", "a"]).write(to: fileURL)
        XCTAssertNil(persistence.loadS1SeenArchive())
        // 同形合法档读得回。
        try archiveJSON(schemaVersion: 1, seenAssetIDs: ["a"]).write(to: fileURL)
        XCTAssertEqual(persistence.loadS1SeenArchive(), S1SeenArchive(seenAssetIDs: ["a"]))
    }

    // MARK: - 断言 2：S2 只记停稳成为当前的那一张

    @MainActor
    func testIC187B_S2RecordsOnlySettledPhotos() throws {
        let (persistence, _) = makePersistence()
        let coordinator = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-看过"))
        completeRead(coordinator, ranges: [monthRange()])
        openRange("范围-月", coordinator: coordinator)
        let machine = try XCTUnwrap(coordinator.s2Machine)

        // 进入时的第一张不经切换即停稳。
        XCTAssertEqual(machine.currentAssetID, "a1")
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1"])
        XCTAssertEqual(coordinator.currentSeenArchive().seenAssetIDs, ["a1"])

        // 上滑标记后自动进入下一张：停在 a2。
        XCTAssertTrue(machine.handleSwipeUp())
        XCTAssertEqual(machine.currentAssetID, "a2")
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1", "a2"])

        // 横栏拖动：途中经过的 a3 不算，拖完停住的 a4 算。
        XCTAssertTrue(machine.beginBottomStripDrag())
        XCTAssertTrue(machine.changeCurrentPhotoDuringBottomStripDrag(by: 1))
        XCTAssertTrue(machine.changeCurrentPhotoDuringBottomStripDrag(by: 1))
        XCTAssertEqual(machine.currentAssetID, "a4")
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1", "a2"])
        XCTAssertTrue(machine.endBottomStripDrag())
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1", "a2", "a4"])

        // 左右翻页：越过半页的切换不算，停稳才算。
        XCTAssertTrue(machine.handleNativePageChange(to: 4))
        XCTAssertEqual(machine.currentAssetID, "a5")
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1", "a2", "a4"])
        machine.notePagingSettled()
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1", "a2", "a4", "a5"])
        // 再停在同一张：集合不变。
        machine.notePagingSettled()
        XCTAssertEqual(machine.visitSeenAssetIDs, ["a1", "a2", "a4", "a5"])

        // 实时并入协调器的看过集合；离开 S2 之前不写盘。
        XCTAssertEqual(coordinator.currentSeenArchive().seenAssetIDs, ["a1", "a2", "a4", "a5"])
        XCTAssertTrue(coordinator.currentSeenArchive().leaveTimeByRangeID.isEmpty)
        XCTAssertNil(persistence.loadS1SeenArchive())
    }

    // MARK: - 断言 3：协调器——离开时刻、写回失败、非活跃写盘、重启读回

    @MainActor
    func testIC187C_CoordinatorRecordsLeaveTimesAndPersists() throws {
        let (persistence, _) = makePersistence()
        let coordinator = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-离开"))
        completeRead(coordinator, ranges: [monthRange()])

        // 第一次进入：看 a1、a5 后返回，写回成功——记离开时刻并写盘。
        openRange("范围-月", coordinator: coordinator)
        let first = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertTrue(first.handleNativePageChange(to: 4))
        first.notePagingSettled()
        let firstPayload = try XCTUnwrap(first.makeExitPayload())
        let before = Date()
        XCTAssertTrue(coordinator.leaveS2(with: firstPayload))
        let after = Date()
        let saved = try XCTUnwrap(persistence.loadS1SeenArchive())
        XCTAssertEqual(saved.seenAssetIDs, ["a1", "a5"])
        let leftAt = try XCTUnwrap(saved.leaveTimeByRangeID["范围-月"])
        XCTAssertTrue(before <= leftAt && leftAt <= after)
        // IC-188：第一次采用范围时已置迁移标记（新会话没有可迁的内容，只置标记），随离开 S2 写盘。
        XCTAssertTrue(saved.hasMigratedLegacyProgress)
        XCTAssertEqual(saved, coordinator.currentSeenArchive())

        // 第二次进入：看 a3 后交回一份会话不符的载荷——写回失败：不记离开时刻，实时记下的 a3 保留并写盘。
        openRange("范围-月", coordinator: coordinator)
        let second = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertTrue(second.handleNativePageChange(to: 2))
        second.notePagingSettled()
        let secondPayload = try XCTUnwrap(second.makeExitPayload())
        let tampered = S2ExitPayload(
            upstreamReturn: SessionStore.S2Return(
                sourceSessionID: "会话-别的",
                sourceRangeID: secondPayload.upstreamReturn.sourceRangeID,
                pendingDeletionAssetIDs: secondPayload.upstreamReturn.pendingDeletionAssetIDs,
                currentAssetID: secondPayload.upstreamReturn.currentAssetID,
                farthestAssetID: secondPayload.upstreamReturn.farthestAssetID
            ),
            continuationSnapshot: secondPayload.continuationSnapshot
        )
        XCTAssertFalse(coordinator.leaveS2(with: tampered))
        XCTAssertEqual(coordinator.route, .s1)
        let afterFailure = try XCTUnwrap(persistence.loadS1SeenArchive())
        XCTAssertTrue(afterFailure.seenAssetIDs.contains("a3"))
        XCTAssertEqual(afterFailure.leaveTimeByRangeID["范围-月"], leftAt)

        // 第三次进入：看 a6 后应用转入非活跃——写盘；不离开 S2 也不记离开时刻。
        openRange("范围-月", coordinator: coordinator)
        let third = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertTrue(third.handleNativePageChange(to: 5))
        third.notePagingSettled()
        XCTAssertFalse(try XCTUnwrap(persistence.loadS1SeenArchive()).seenAssetIDs.contains("a6"))
        coordinator.setApplicationActive(false)
        XCTAssertTrue(try XCTUnwrap(persistence.loadS1SeenArchive()).seenAssetIDs.contains("a6"))
        coordinator.setApplicationActive(true)
        let thirdPayload = try XCTUnwrap(third.makeExitPayload())
        XCTAssertTrue(coordinator.leaveS2(with: thirdPayload))

        // 虚拟范围（类别页长按进入）同样记看过与离开时刻。
        let s1Machine = try XCTUnwrap(coordinator.s1Machine)
        let virtualHandoff = try XCTUnwrap(
            s1Machine.makeS2Handoff(
                virtualRangeID: "cat:video",
                displayName: "视频",
                orderedAssetIDs: ["v1", "v2"],
                currentAssetID: "v2"
            )
        )
        XCTAssertTrue(coordinator.enterS2(from: virtualHandoff))
        let virtualMachine = try XCTUnwrap(coordinator.s2Machine)
        XCTAssertEqual(virtualMachine.visitSeenAssetIDs, ["v2"])
        let virtualPayload = try XCTUnwrap(virtualMachine.makeExitPayload())
        XCTAssertTrue(coordinator.leaveS2(with: virtualPayload))
        let finalArchive = try XCTUnwrap(persistence.loadS1SeenArchive())
        // IC-188：第二、三次进入从第一张没看过的开始（a2、a4），进入时的第一张即看过。
        XCTAssertEqual(finalArchive.seenAssetIDs, ["a1", "a2", "a3", "a4", "a5", "a6", "v2"])
        XCTAssertNotNil(finalArchive.leaveTimeByRangeID["cat:video"])
        XCTAssertEqual(Set(finalArchive.leaveTimeByRangeID.keys), ["范围-月", "cat:video"])

        // 换一个协调器（进程重启、开新会话）：读回同一份档，不随会话清。
        let restarted = CleanupCoordinator(persistence: persistence)
        XCTAssertTrue(restarted.enterS1(sessionID: "会话-新"))
        XCTAssertEqual(restarted.currentSeenArchive(), finalArchive)
    }

    // MARK: - 断言 4：源码落位

    func testIC187D_SourceWiring() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        XCTAssertEqual(occurrences(of: "private(set) var visitSeenAssetIDs: Set<String> = []", in: machine), 1)
        XCTAssertEqual(occurrences(of: "private let seenAssetDidSettle: (String) -> Void", in: machine), 1)
        XCTAssertEqual(occurrences(of: "seenAssetDidSettle: @escaping (String) -> Void = { _ in }", in: machine), 1)
        XCTAssertEqual(occurrences(of: "visitSeenAssetIDs = [entry.currentAssetID]", in: machine), 1)
        XCTAssertEqual(occurrences(of: "func notePagingSettled() {", in: machine), 1)
        XCTAssertEqual(occurrences(of: "private func markCurrentSeen() {", in: machine), 1)
        // 汇集口一处定义 + 三处调用：`switchPhoto`、`endBottomStripDrag`、`notePagingSettled`。
        XCTAssertEqual(occurrences(of: "markCurrentSeen()", in: machine), 4)
        XCTAssertEqual(occurrences(of: "guard bottomStripState == .idle else {", in: machine), 1)
        XCTAssertEqual(occurrences(of: "seenAssetDidSettle(assetID)", in: machine), 1)
        // 越过半页的切换与上滑入口本身不记（上滑经 `switchPhoto` 记）。
        let pageChange = try XCTUnwrap(slice(machine, from: "func handleNativePageChange(to index: Int) -> Bool {", to: "return true"))
        XCTAssertEqual(occurrences(of: "markCurrentSeen()", in: pageChange), 0)
        let swipeUp = try XCTUnwrap(slice(machine, from: "func handleSwipeUp() -> Bool {", to: "func handleSwipeDown() -> Bool {"))
        XCTAssertEqual(occurrences(of: "markCurrentSeen()", in: swipeUp), 0)
        XCTAssertEqual(occurrences(of: "switchPhoto(by: 1)", in: swipeUp), 1)
        let endStrip = try XCTUnwrap(slice(machine, from: "func endBottomStripDrag() -> Bool {", to: "return true"))
        XCTAssertEqual(occurrences(of: "markCurrentSeen()", in: endStrip), 1)
        let switchBody = try XCTUnwrap(slice(machine, from: "private func switchPhoto(by offset: Int) -> Bool {", to: "return true"))
        XCTAssertEqual(occurrences(of: "markCurrentSeen()", in: switchBody), 1)

        let view = try XCTUnwrap(strippedSource(Self.viewPath))
        XCTAssertEqual(occurrences(of: "machine.notePagingSettled()", in: view), 1)
        let settled = try XCTUnwrap(slice(view, from: "onPagingSettled: {", to: "},"))
        XCTAssertEqual(occurrences(of: "machine.notePagingSettled()", in: settled), 1)
        XCTAssertEqual(occurrences(of: "livePlayback.pagingSettled()", in: settled), 1)
        XCTAssertEqual(occurrences(of: "videoPlayback.pagingSettled()", in: settled), 1)

        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "func currentSeenArchive() -> S1SeenArchive {", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "private func flushSeenArchive() {", in: coordinator), 1)
        // 单一写出口：一处定义 + 写回之后（`defer`）+ 转入非活跃 + IC-188 迁移并入了内容之后。
        XCTAssertEqual(occurrences(of: "flushSeenArchive()", in: coordinator), 4)
        XCTAssertEqual(occurrences(of: "persistence.saveS1SeenArchive(", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "persistence.loadS1SeenArchive()", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "seenAssetDidSettle: { [weak self] assetID in", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "recordSeenAssets(", in: coordinator), 4)
        XCTAssertEqual(occurrences(of: "recordS2Leave(", in: coordinator), 2)
        let finish = try XCTUnwrap(slice(coordinator, from: "private func finishSession() {", to: "private func restorePersistedSession() -> Bool {"))
        XCTAssertEqual(occurrences(of: "Seen", in: finish), 0)

        let persistence = try XCTUnwrap(strippedSource(Self.persistencePath))
        let persistenceRaw = try XCTUnwrap(sourceText(Self.persistencePath))
        XCTAssertEqual(occurrences(of: Self.quote + "s1-seen.json" + Self.quote, in: persistenceRaw), 1)
        XCTAssertEqual(occurrences(of: "func saveS1SeenArchive(_ archive: S1SeenArchive) throws {", in: persistence), 1)
        XCTAssertEqual(occurrences(of: "func loadS1SeenArchive() -> S1SeenArchive? {", in: persistence), 1)
        XCTAssertEqual(occurrences(of: "clearS1SeenArchive", in: persistence), 0)

        let archiveRaw = try XCTUnwrap(sourceText(Self.archivePath))
        let archive = try XCTUnwrap(strippedSource(Self.archivePath))
        XCTAssertEqual(occurrences(of: "import ", in: archiveRaw), 1)
        XCTAssertEqual(occurrences(of: "import Foundation", in: archiveRaw), 1)
        for needle in ["Photos", "PHAsset", "L10n.", "@MainActor", "S0"] {
            XCTAssertEqual(occurrences(of: needle, in: archive), 0, needle)
        }
        XCTAssertEqual(occurrences(of: "static let currentSchemaVersion = 1", in: archive), 1)
    }

    // MARK: - 夹具

    private func makePersistence() -> (SessionPersistence, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IC187-" + UUID().uuidString, isDirectory: true)
        temporaryRoots.append(root)
        let persistence = SessionPersistence(
            fileManager: IsolatedFileManager(applicationSupportRoot: root)
        )
        return (persistence, root.appendingPathComponent("PhotoCleanupMVE", isDirectory: true))
    }

    private func monthRange() -> S1Range {
        S1Range(
            id: "范围-月",
            displayName: "2026 年 9 月",
            assetIDsNewestFirst: ["a1", "a2", "a3", "a4", "a5", "a6"]
        )
    }

    @MainActor
    private func completeRead(_ coordinator: CleanupCoordinator, ranges: [S1Range]) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
    }

    @MainActor
    private func openRange(_ rangeID: String, coordinator: CleanupCoordinator) {
        guard let handoff = coordinator.s1Machine?.makeS2Handoff(for: rangeID) else {
            return XCTFail("应形成 S1 到 S2 的交接")
        }
        XCTAssertTrue(coordinator.enterS2(from: handoff))
    }

    /// 双引号用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的教训）。
    private static let quote = String(Character(UnicodeScalar(UInt8(34))))

    /// 手写一份看过档 JSON。字段用数组拼接、不写长 `+` 链（陷阱 16：类型检查超时）。
    private func archiveJSON(schemaVersion: Int, seenAssetIDs: [String]) -> Data {
        let quote = Self.quote
        let identifiers = seenAssetIDs.map { quote + $0 + quote }.joined(separator: ",")
        let fields: [String] = [
            quote + "schemaVersion" + quote + ":" + String(schemaVersion),
            quote + "seenAssetIDs" + quote + ":[" + identifiers + "]",
            quote + "leaveTimeByRangeID" + quote + ":{}",
            quote + "hasMigratedLegacyProgress" + quote + ":false"
        ]
        return Data(("{" + fields.joined(separator: ",") + "}").utf8)
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
