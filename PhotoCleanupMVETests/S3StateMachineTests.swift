import Foundation
import XCTest
@testable import PhotoCleanupMVE

final class S3StateMachineTests: XCTestCase {
    // 可达单元格 01：从页面外进入 S3。
    func testCell01EnterFromOutsideWithEmptySetRoutesToS3_4() {
        let machine = S3StateMachine(assets: [])

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.assetCount, 0)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    func testCell01EnterFromOutsideOverLimitRoutesToS3_3WithoutQueueing() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertEqual(machine.state, .overLimit)
        XCTAssertEqual(machine.assetCount, 201)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
        XCTAssertEqual(machine.cachedConclusion(for: "asset-0"), .notStarted)
    }

    func testCell01EnterFromOutsideWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted() {
        let input = [asset("a"), asset("b"), asset("c"), asset("d")]
        let cache: [String: AssetScanConclusion] = [
            "a": .notStarted,
            "b": .inProgress,
            "c": .knownBytes(12),
            "d": .unavailable
        ]

        let machine = S3StateMachine(assets: input, cachedConclusions: cache)

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.pendingScanAssetIDs, ["a"])
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .inProgress)
        XCTAssertEqual(machine.cachedConclusion(for: "b"), .inProgress)
    }

    func testCell01EnterFromOutsideWithCompletedCacheRoutesToS3_2WithoutRescan() {
        let input = [asset("a"), asset("b")]
        let cache: [String: AssetScanConclusion] = [
            "a": .knownBytes(12),
            "b": .unavailable
        ]

        let machine = S3StateMachine(assets: input, cachedConclusions: cache)

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 12)
        XCTAssertEqual(machine.unavailableCount, 1)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    // 可达单元格 02：S3-1 收到全部扫描结论后进入 S3-2。
    func testCell02ScanCompletionFromS3_1RoutesToS3_2() {
        let machine = S3StateMachine(assets: [asset("a"), asset("b")])

        XCTAssertTrue(machine.recordScanSuccess(for: "a", byteCount: 20))
        XCTAssertEqual(machine.state, .scanning)
        XCTAssertTrue(machine.recordScanFailure(for: "b"))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 20)
        XCTAssertEqual(machine.unavailableCount, 1)
    }

    // 可达单元格 03：S3-1 的“扫描中移除项”事件。
    func testCell03RemoveDuringScanLastItemRoutesToS3_4() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertTrue(machine.removeAsset(identifier: "a"))

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .inProgress)
    }

    func testCell03RemoveDuringScanLastIncompleteItemRoutesToS3_2() {
        let machine = S3StateMachine(
            assets: [asset("known"), asset("running")],
            cachedConclusions: ["known": .knownBytes(50), "running": .inProgress]
        )

        XCTAssertTrue(machine.removeAsset(identifier: "running"))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 50)
        XCTAssertEqual(machine.cachedConclusion(for: "running"), .inProgress)
    }

    func testCell03RemoveDuringScanWhileIncompleteItemRemainsStaysInS3_1() {
        let machine = S3StateMachine(
            assets: [asset("known"), asset("running")],
            cachedConclusions: ["known": .knownBytes(50), "running": .inProgress]
        )

        XCTAssertTrue(machine.removeAsset(identifier: "known"))

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.knownTotalBytes, 0)
        XCTAssertEqual(machine.cachedConclusion(for: "known"), .knownBytes(50))
    }

    // 可达单元格 04：S3-1 的“移除单项”事件，结果为空。
    func testCell04RemoveOneFromS3_1LastItemRoutesToS3_4() {
        let machine = S3StateMachine(assets: [asset("removed")])

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertTrue(machine.removeAsset(identifier: "removed"))

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "removed"), .inProgress)
    }

    // 可达单元格 04：S3-1 的“移除单项”事件，移除最后一个未完成项。
    func testCell04RemoveOneFromS3_1LastIncompleteItemRoutesToS3_2() {
        let machine = S3StateMachine(
            assets: [asset("known"), asset("running")],
            cachedConclusions: ["known": .knownBytes(50), "running": .inProgress]
        )

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertTrue(machine.removeAsset(identifier: "running"))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 50)
        XCTAssertEqual(machine.cachedConclusion(for: "running"), .inProgress)
    }

    // 可达单元格 04：S3-1 的“移除单项”事件，仍有未完成项。
    func testCell04RemoveOneFromS3_1WhileIncompleteItemRemainsStaysInS3_1() {
        let machine = S3StateMachine(
            assets: [asset("removed"), asset("running"), asset("failed")],
            cachedConclusions: [
                "removed": .knownBytes(90),
                "running": .inProgress,
                "failed": .unavailable
            ]
        )

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertTrue(machine.removeAsset(identifier: "removed"))

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.knownTotalBytes, 0)
        XCTAssertEqual(machine.unavailableCount, 1)
        XCTAssertEqual(machine.cachedConclusion(for: "removed"), .knownBytes(90))
    }

    // 可达单元格 05：S3-2 移除单项。
    func testCell05RemoveOneFromS3_2WhileNonEmptyStaysInS3_2() {
        let machine = S3StateMachine(
            assets: [asset("a"), asset("b")],
            cachedConclusions: ["a": .knownBytes(10), "b": .unavailable]
        )

        XCTAssertTrue(machine.removeAsset(identifier: "a"))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 0)
        XCTAssertEqual(machine.unavailableCount, 1)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .knownBytes(10))
    }

    func testCell05RemoveLastItemFromS3_2RoutesToS3_4() {
        let machine = S3StateMachine(
            assets: [asset("a")],
            cachedConclusions: ["a": .knownBytes(10)]
        )

        XCTAssertTrue(machine.removeAsset(identifier: "a"))

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .knownBytes(10))
    }

    // 可达单元格 06：S3-3 移除单项。
    func testCell06RemoveOneFromS3_3WhileStillOverLimitStaysInS3_3() {
        let machine = S3StateMachine(assets: makeAssets(count: 202))

        XCTAssertTrue(machine.removeAsset(identifier: "asset-0"))

        XCTAssertEqual(machine.state, .overLimit)
        XCTAssertEqual(machine.assetCount, 201)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    func testCell06RemoveOneFromS3_3ToLimitWithIncompleteItemsRoutesToS3_1() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertTrue(machine.removeAsset(identifier: "asset-200"))

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.assetCount, 200)
        XCTAssertEqual(machine.pendingScanAssetIDs, machine.assetIDs)
    }

    func testCell06RemoveOneFromS3_3ToLimitWithCompletedCacheRoutesToS3_2() {
        let input = makeAssets(count: 201)
        let cache = Dictionary(
            uniqueKeysWithValues: input.map { ($0.identifier, AssetScanConclusion.knownBytes(1)) }
        )
        let machine = S3StateMachine(assets: input, cachedConclusions: cache)

        XCTAssertTrue(machine.removeAsset(identifier: "asset-200"))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 200)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    // 可达单元格 07 至 09：三个非空状态均可全部取消。
    func testCell07CancelAllFromS3_1RoutesToS3_4AndKeepsCache() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertTrue(machine.cancelAll())

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .inProgress)
    }

    func testCell08CancelAllFromS3_2RoutesToS3_4AndKeepsCache() {
        let machine = S3StateMachine(
            assets: [asset("a")],
            cachedConclusions: ["a": .knownBytes(10)]
        )

        XCTAssertTrue(machine.cancelAll())

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .knownBytes(10))
    }

    func testCell09CancelAllFromS3_3RoutesToS3_4AndKeepsCache() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertTrue(machine.cancelAll())

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "asset-0"), .notStarted)
    }

    // 可达单元格 10：S3-3 的选择数回落至上限内。
    func testCell10FallToLimitWithIncompleteItemsRoutesToS3_1AndQueuesOnlyNotStarted() {
        let input = makeAssets(count: 201)
        var cache = Dictionary(uniqueKeysWithValues: input.map { ($0.identifier, AssetScanConclusion.knownBytes(1)) })
        cache["asset-0"] = .notStarted
        cache["asset-1"] = .inProgress
        let machine = S3StateMachine(assets: input, cachedConclusions: cache)

        XCTAssertTrue(machine.reduceSelectionTo(assetIDs: Array(machine.assetIDs.prefix(200))))

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.pendingScanAssetIDs, ["asset-0"])
        XCTAssertEqual(machine.cachedConclusion(for: "asset-1"), .inProgress)
    }

    func testCell10FallToLimitWithCompletedCacheRoutesToS3_2() {
        let input = makeAssets(count: 201)
        let cache = Dictionary(uniqueKeysWithValues: input.map { ($0.identifier, AssetScanConclusion.knownBytes(1)) })
        let machine = S3StateMachine(assets: input, cachedConclusions: cache)

        XCTAssertTrue(machine.reduceSelectionTo(assetIDs: Array(machine.assetIDs.prefix(200))))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.assetCount, 200)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    func testCell10FallToZeroUsesEmptySetRule() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertTrue(machine.reduceSelectionTo(assetIDs: []))

        XCTAssertEqual(machine.state, .empty)
    }

    // 可达单元格 11 至 13：集合变为空事件。
    func testCell11CollectionBecameEmptyFromS3_1RoutesToS3_4() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertTrue(machine.collectionBecameEmpty())

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .inProgress)
    }

    func testCell12CollectionBecameEmptyFromS3_2RoutesToS3_4() {
        let machine = S3StateMachine(
            assets: [asset("a")],
            cachedConclusions: ["a": .unavailable]
        )

        XCTAssertTrue(machine.collectionBecameEmpty())

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .unavailable)
    }

    func testCell13CollectionBecameEmptyFromS3_3RoutesToS3_4() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertTrue(machine.collectionBecameEmpty())

        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.cachedConclusion(for: "asset-0"), .notStarted)
    }

    // 可达单元格 14：S3-2 点击提交。
    func testCell14SubmitFromS3_2FreezesSnapshotForS4_1() {
        let frozenAt = Date(timeIntervalSince1970: 123)
        let machine = S3StateMachine(
            assets: [asset("a", favorite: true), asset("b")],
            cachedConclusions: ["a": .knownBytes(40), "b": .unavailable],
            submissionIDGenerator: { "submission-1" },
            clock: { frozenAt }
        )

        guard case let .frozen(snapshot) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("应成功冻结快照")
        }

        XCTAssertEqual(snapshot.submissionID, "submission-1")
        XCTAssertEqual(snapshot.assetIDs, ["a", "b"])
        XCTAssertEqual(snapshot.assetCount, 2)
        XCTAssertEqual(snapshot.knownTotalBytes, 40)
        XCTAssertEqual(snapshot.unavailableCount, 1)
        XCTAssertEqual(snapshot.volumeDisplayMode, .lowerBound)
        XCTAssertEqual(snapshot.favoriteAssetIDs, Set(["a"]))
        XCTAssertEqual(snapshot.frozenAt, frozenAt)
        XCTAssertEqual(machine.frozenSnapshot, snapshot)
    }

    // 以下测试独立验证冻结守卫，不冒充从 S3-2 出发的竞态迁移。
    func testFreezeCountGuardRejectsEmptySetAndFormsNoSnapshot() {
        let machine = S3StateMachine(assets: [])

        XCTAssertEqual(
            machine.freezeSubmissionSnapshot(),
            .rejected(.invalidState(.empty))
        )
        XCTAssertNil(machine.frozenSnapshot)
    }

    func testFreezeCountGuardRejectsOverLimitSetAndFormsNoSnapshot() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertEqual(
            machine.freezeSubmissionSnapshot(),
            .rejected(.invalidState(.overLimit))
        )
        XCTAssertNil(machine.frozenSnapshot)
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    func testFreezeCompletionGuardRejectsS3_1AndFormsNoSnapshot() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertEqual(
            machine.freezeSubmissionSnapshot(),
            .rejected(.invalidState(.scanning))
        )
        XCTAssertNil(machine.frozenSnapshot)
    }

    func testDisabledOperationsInS3_4HaveNoEffect() {
        let machine = S3StateMachine(assets: [])

        XCTAssertFalse(machine.removeAsset(identifier: "missing"))
        XCTAssertFalse(machine.cancelAll())
        XCTAssertFalse(machine.collectionBecameEmpty())
        XCTAssertEqual(machine.state, .empty)
    }

    func testSelectionFallbackRejectsAdditionAndMoreThanLimit() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))
        let originalIDs = machine.assetIDs

        XCTAssertFalse(machine.reduceSelectionTo(assetIDs: ["outside"]))
        XCTAssertFalse(machine.reduceSelectionTo(assetIDs: originalIDs))
        XCTAssertEqual(machine.assetIDs, originalIDs)
        XCTAssertEqual(machine.state, .overLimit)
    }

    func testUnknownOrNegativeScanResultIsRejectedWithoutChangingCache() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertFalse(machine.recordScanSuccess(for: "unknown", byteCount: 1))
        XCTAssertFalse(machine.recordScanFailure(for: "unknown"))
        XCTAssertFalse(machine.recordScanSuccess(for: "a", byteCount: -1))
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .inProgress)
        XCTAssertNil(machine.cachedConclusion(for: "unknown"))
    }

    private func asset(_ identifier: String, favorite: Bool = false) -> AssetDescriptor {
        AssetDescriptor(identifier: identifier, isFavorite: favorite)
    }

    private func makeAssets(count: Int) -> [AssetDescriptor] {
        (0..<count).map { asset("asset-\($0)") }
    }
}
