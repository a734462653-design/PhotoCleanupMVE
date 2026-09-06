import XCTest
@testable import PhotoCleanupMVE

/// IC-132 A：范围显示名随会话档持久化（根因修复）。
///
/// 缺陷链条：`knownRangeNamesByID` 原先只由本次读到的 `R(T)` 填充、不入档，
/// 而 `makeS3Submission()` 要求 `M` 中每个已标记范围都有已知名字。于是「在相册
/// 维度标记 → 杀应用 → 重开停在按日期维度」之后，相册范围的名字永远补不齐，
/// 提交恒为 nil。
final class IC132S1RangeNamePersistenceTests: XCTestCase {
    // 断言 1a：名字表确实跨「快照 → 编解码 → restore」存活。
    //
    // 注：卡内断言 1 原文要求「在读取任何 R(T) 之前」调用 makeS3Submission()
    // 返回非 nil。实测不成立，且与本卡无关——`makeS3Submission()` 头一条守卫是
    // `state != .loading`，而 `restore` 出来的状态机以 `.loading` 起步；改这条
    // 守卫属本卡范围外（「不改 makeS3Submission() 的 nil 条件」）。此处如实钉住
    // 「此刻为 nil，且原因是加载态而非名字缺失」，名字可用性由断言 1b 证明。
    func testIC132A_RangeNamesSurviveArchiveRoundTrip() throws {
        let original = makeMarkedMachine()
        let originalNames = original.sessionSnapshot.rangeNamesByID
        XCTAssertEqual(
            originalNames,
            ["相册-1": "家庭", "相册-2": "旅行"]
        )

        // 快照 → PersistedS1Session 编码 → 解码 → 快照 → restore。
        let encoded = try JSONEncoder().encode(
            PersistedS1Session(original.sessionSnapshot)
        )
        let decoded = try JSONDecoder().decode(
            PersistedS1Session.self,
            from: encoded
        )
        let restoredSnapshot = tryUnwrap(decoded.snapshot)
        XCTAssertEqual(restoredSnapshot.rangeNamesByID, originalNames)

        let restored = tryUnwrap(S1StateMachine.restore(from: restoredSnapshot))
        // 名字表已灌回，读取任何 R(T) 之前即可见。
        XCTAssertEqual(restored.sessionSnapshot.rangeNamesByID, originalNames)
        XCTAssertEqual(restored.badgeCount, 3)
        // 此刻仍为 nil——原因是加载态守卫，不是名字缺失（见上方注）。
        XCTAssertEqual(restored.state, .loading)
        XCTAssertNil(restored.makeS3Submission())
    }

    // 断言 1b：恢复后切到一个**读不到那些范围**的维度（相册范围不在 R(date) 中，
    // 本次读取一个名字都没提供），仍能形成提交，且分组名与原显示名逐字相等。
    // 这正是「隔天回来点垃圾桶」的现场。
    func testIC132A_SubmissionUsesArchivedNamesWhenReadSuppliesNone() throws {
        let original = makeMarkedMachine()
        let encoded = try JSONEncoder().encode(
            PersistedS1Session(original.sessionSnapshot)
        )
        let decoded = try JSONDecoder().decode(
            PersistedS1Session.self,
            from: encoded
        )
        let restored = tryUnwrap(
            S1StateMachine.restore(from: tryUnwrap(decoded.snapshot))
        )

        // 读到空 R(T)：不提供任何名字。
        let request = tryUnwrap(restored.currentReadRequest)
        XCTAssertTrue(restored.completeRangeRead(.success([]), for: request))
        XCTAssertEqual(restored.state, .empty)

        let submission = tryUnwrap(restored.makeS3Submission())
        XCTAssertEqual(
            Set(submission.orderedAssetIDs),
            ["资产-A", "资产-B", "资产-C"]
        )
        // 分组名逐字来自档里的名字表。
        let namesByRangeID = Dictionary(
            uniqueKeysWithValues: submission.groups.map {
                ($0.sourceRangeID, $0.name)
            }
        )
        XCTAssertEqual(
            namesByRangeID,
            ["相册-1": "家庭", "相册-2": "旅行"]
        )
    }

    // 断言 2：旧档（没有 rangeNamesByID 键）解码成功、名字表为空、其余字段正确。
    // 手工按 IC-127 B 落地的格式构造，不经当前编码器，才是真的「旧档」。
    func testIC132A_LegacyArchiveWithoutRangeNamesDecodesAsEmptyTable() throws {
        let legacy: [String: Any] = [
            "sessionID": "会话-旧档",
            "groupingDimension": "album",
            "sortOrder": "oldestFirst",
            "pendingDeletionAssetIDsByRangeID": [
                "相册-1": ["资产-A", "资产-B"]
            ],
            "continuationsByRangeID": [
                "相册-1": [
                    "currentAssetID": "资产-B",
                    "farthestAssetID": "资产-A",
                    "recordedSortOrder": "oldestFirst"
                ]
            ],
            "firstMarkedRangeIDByAssetID": [
                "资产-A": "相册-1",
                "资产-B": "相册-1"
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)

        // 不判坏档。
        let decoded = try JSONDecoder().decode(PersistedS1Session.self, from: data)
        XCTAssertEqual(decoded.rangeNamesByID, [:])

        let snapshot = tryUnwrap(decoded.snapshot)
        XCTAssertEqual(snapshot.rangeNamesByID, [:])
        // 其余字段原样。
        XCTAssertEqual(snapshot.sessionID, "会话-旧档")
        XCTAssertEqual(snapshot.groupingDimension, .album)
        XCTAssertEqual(snapshot.sortOrder, .oldestFirst)
        XCTAssertEqual(
            snapshot.pendingDeletionAssetIDsByRangeID,
            ["相册-1": ["资产-A", "资产-B"]]
        )
        XCTAssertEqual(
            snapshot.continuationsByRangeID,
            [
                "相册-1": SessionStore.Continuation(
                    currentAssetID: "资产-B",
                    farthestAssetID: "资产-A",
                    recordedSortOrder: .oldestFirst
                )
            ]
        )
        XCTAssertEqual(
            snapshot.firstMarkedRangeIDByAssetID,
            ["资产-A": "相册-1", "资产-B": "相册-1"]
        )
        // 旧档恢复出的状态机可用，只是名字表空（由子项 B 兜底，不再静默）。
        XCTAssertNotNil(S1StateMachine.restore(from: snapshot))
    }

    // 断言 3：单一写出口——引入新范围名写出恰增 1；同一批范围再读一次不写。
    func testIC132A_NewRangeNamesPublishExactlyOnceThroughSingleSink() {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-132A-写出口"),
            initialGroupingDimension: .album,
            initialSortOrder: .newestFirst
        )
        var published: [S1SessionSnapshot] = []
        machine.persistenceSink = { published.append($0) }
        XCTAssertEqual(published.count, 0)

        // 首次读到两个范围：名字表由空变为两条，store 无需收敛。
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success(albumRanges), for: request))
        XCTAssertEqual(published.count, 1)
        XCTAssertEqual(
            published.last?.rangeNamesByID,
            ["相册-1": "家庭", "相册-2": "旅行"]
        )

        // 同一批范围再对账一次：快照无变化，不写。
        XCTAssertTrue(machine.reconcile(with: .success(albumRanges)))
        XCTAssertEqual(published.count, 1)
    }

    // MARK: - 夹具

    private var albumRanges: [S1Range] {
        [
            S1Range(
                id: "相册-1",
                displayName: "家庭",
                assetIDsNewestFirst: ["资产-B", "资产-A"]
            ),
            S1Range(
                id: "相册-2",
                displayName: "旅行",
                assetIDsNewestFirst: ["资产-C"]
            )
        ]
    }

    /// 在相册维度读到两个范围并各标记若干张（共 3 张）。
    private func makeMarkedMachine() -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "会话-132A"),
            initialGroupingDimension: .album,
            initialSortOrder: .newestFirst
        )
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(machine.completeRangeRead(.success(albumRanges), for: request))
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-A", "资产-B"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "相册-1",
                    orderedAssetIDs: ["资产-B", "资产-A"],
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["资产-C"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "相册-2",
                    orderedAssetIDs: ["资产-C"],
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
        XCTAssertEqual(machine.badgeCount, 3)
        return machine
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("期望非空值", file: file, line: line)
            fatalError("期望非空值")
        }
        return value
    }
}
