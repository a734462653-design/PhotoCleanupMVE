import Foundation
import XCTest
@testable import PhotoCleanupMVE

final class SnapshotInvariantTests: XCTestCase {
    func testDIsDeduplicatedWithoutChangingFirstOccurrenceOrder() {
        let machine = S3StateMachine(
            assets: [
                asset("b", favorite: true),
                asset("a"),
                asset("b"),
                asset("c")
            ],
            cachedConclusions: [
                "a": .knownBytes(1),
                "b": .knownBytes(2),
                "c": .knownBytes(3)
            ]
        )

        XCTAssertEqual(machine.assetIDs, ["b", "a", "c"])
        XCTAssertEqual(machine.assetCount, 3)
        XCTAssertTrue(machine.assets[0].isFavorite)
    }

    func testOverLimitKeepsEveryDeduplicatedAssetInsteadOfTruncatingAt200() {
        let machine = S3StateMachine(assets: makeAssets(count: 205))

        XCTAssertEqual(machine.state, .overLimit)
        XCTAssertEqual(machine.assetCount, 205)
        XCTAssertEqual(machine.assetIDs.last, "asset-204")
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
    }

    func testSubmissionLimitUsesDeduplicatedAssetCount() {
        var input = makeAssets(count: 200)
        input.append(asset("asset-0"))

        let machine = S3StateMachine(assets: input)

        XCTAssertEqual(machine.assetCount, 200)
        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.pendingScanAssetIDs.count, 200)
    }

    func testKnownBytesAndUnavailableCountAreRecomputedFromCurrentD() {
        let machine = S3StateMachine(
            assets: [asset("a"), asset("b"), asset("c")],
            cachedConclusions: [
                "a": .knownBytes(10),
                "b": .knownBytes(20),
                "c": .unavailable
            ]
        )

        XCTAssertEqual(machine.knownTotalBytes, 30)
        XCTAssertEqual(machine.unavailableCount, 1)
        XCTAssertTrue(machine.removeAsset(identifier: "b"))
        XCTAssertEqual(machine.knownTotalBytes, 10)
        XCTAssertEqual(machine.unavailableCount, 1)
        XCTAssertTrue(machine.removeAsset(identifier: "c"))
        XCTAssertEqual(machine.knownTotalBytes, 10)
        XCTAssertEqual(machine.unavailableCount, 0)
    }

    func testRemovingAssetRetainsItsOnlyCachedConclusion() {
        let machine = S3StateMachine(
            assets: [asset("a"), asset("b")],
            cachedConclusions: ["a": .knownBytes(10), "b": .knownBytes(20)]
        )

        XCTAssertTrue(machine.removeAsset(identifier: "a"))

        XCTAssertEqual(machine.cachedConclusion(for: "a"), .knownBytes(10))
        XCTAssertEqual(machine.conclusionCache.count, 2)
    }

    func testRemovingQueuedAssetDoesNotInvalidateItsQueuedWork() {
        let machine = S3StateMachine(assets: [asset("a"), asset("b")])

        XCTAssertTrue(machine.removeAsset(identifier: "a"))

        XCTAssertEqual(machine.takePendingScanAssetIDs(), ["a", "b"])
        XCTAssertEqual(machine.cachedConclusion(for: "a"), .inProgress)
    }

    func testLateSuccessForCurrentAssetImmediatelyUpdatesCurrentStatistics() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertTrue(machine.recordScanSuccess(for: "a", byteCount: 99))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 99)
        XCTAssertEqual(machine.unavailableCount, 0)
    }

    func testLateFailureForCurrentAssetImmediatelyUpdatesCurrentStatistics() {
        let machine = S3StateMachine(assets: [asset("a")])

        XCTAssertTrue(machine.recordScanFailure(for: "a"))

        XCTAssertEqual(machine.state, .ready)
        XCTAssertEqual(machine.knownTotalBytes, 0)
        XCTAssertEqual(machine.unavailableCount, 1)
    }

    func testLateResultForRemovedAssetUpdatesCacheButNotCurrentStatistics() {
        let machine = S3StateMachine(assets: [asset("removed"), asset("kept")])
        XCTAssertTrue(machine.removeAsset(identifier: "removed"))

        XCTAssertTrue(machine.recordScanSuccess(for: "removed", byteCount: 500))

        XCTAssertEqual(machine.cachedConclusion(for: "removed"), .knownBytes(500))
        XCTAssertEqual(machine.knownTotalBytes, 0)
        XCTAssertEqual(machine.state, .scanning)
    }

    func testReentryReusesCompletedCacheWithoutQueueingAgain() {
        let first = S3StateMachine(assets: [asset("a"), asset("b")])
        XCTAssertTrue(first.recordScanSuccess(for: "a", byteCount: 10))
        XCTAssertTrue(first.recordScanFailure(for: "b"))

        let reentered = S3StateMachine(
            assets: [asset("a"), asset("b")],
            cachedConclusions: first.conclusionCache
        )

        XCTAssertEqual(reentered.state, .ready)
        XCTAssertEqual(reentered.knownTotalBytes, 10)
        XCTAssertEqual(reentered.unavailableCount, 1)
        XCTAssertTrue(reentered.pendingScanAssetIDs.isEmpty)
    }

    func testTakingQueueDoesNotQueueInProgressAssetsAgain() {
        let machine = S3StateMachine(assets: [asset("a"), asset("b")])

        XCTAssertEqual(machine.takePendingScanAssetIDs(), ["a", "b"])
        XCTAssertTrue(machine.takePendingScanAssetIDs().isEmpty)
        XCTAssertTrue(machine.recordScanSuccess(for: "a", byteCount: 1))
        XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty)
        XCTAssertEqual(machine.cachedConclusion(for: "b"), .inProgress)
    }

    func testOneUnavailableConclusionDoesNotStopOtherScans() {
        let machine = S3StateMachine(assets: [asset("a"), asset("b")])

        XCTAssertTrue(machine.recordScanFailure(for: "a"))

        XCTAssertEqual(machine.state, .scanning)
        XCTAssertEqual(machine.cachedConclusion(for: "b"), .inProgress)
        XCTAssertTrue(machine.recordScanSuccess(for: "b", byteCount: 5))
        XCTAssertEqual(machine.state, .ready)
    }

    func testFavoriteAssetsUseSameScanRulesAndRemainSubmittable() {
        let machine = S3StateMachine(assets: [asset("favorite", favorite: true)])

        XCTAssertEqual(machine.pendingScanAssetIDs, ["favorite"])
        XCTAssertTrue(machine.recordScanSuccess(for: "favorite", byteCount: 7))
        XCTAssertTrue(machine.canSubmit)

        guard case let .frozen(snapshot) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("收藏项也应允许提交")
        }
        XCTAssertEqual(snapshot.favoriteAssetIDs, Set(["favorite"]))
    }

    func testSnapshotUsesExactModeWhenEveryAssetHasKnownBytes() {
        let machine = readyMachine(
            assets: [asset("a"), asset("b")],
            conclusions: ["a": .knownBytes(10), "b": .knownBytes(20)]
        )

        guard case let .frozen(snapshot) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("应成功冻结快照")
        }

        XCTAssertEqual(snapshot.knownTotalBytes, 30)
        XCTAssertEqual(snapshot.unavailableCount, 0)
        XCTAssertEqual(snapshot.volumeDisplayMode, .exact)
    }

    func testSnapshotUsesLowerBoundModeWhenAnyAssetIsUnavailable() {
        let machine = readyMachine(
            assets: [asset("a"), asset("b")],
            conclusions: ["a": .knownBytes(10), "b": .unavailable]
        )

        guard case let .frozen(snapshot) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("应成功冻结快照")
        }

        XCTAssertEqual(snapshot.knownTotalBytes, 10)
        XCTAssertEqual(snapshot.unavailableCount, 1)
        XCTAssertEqual(snapshot.volumeDisplayMode, .lowerBound)
    }

    func testSnapshotRemainsImmutableAfterCacheReceivesAnotherResult() {
        let machine = readyMachine(
            assets: [asset("a")],
            conclusions: ["a": .knownBytes(10)]
        )

        guard case let .frozen(snapshot) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("应成功冻结快照")
        }
        XCTAssertTrue(machine.recordScanSuccess(for: "a", byteCount: 999))

        XCTAssertEqual(snapshot.knownTotalBytes, 10)
        XCTAssertEqual(machine.frozenSnapshot?.knownTotalBytes, 10)
        XCTAssertEqual(machine.knownTotalBytes, 999)
    }

    func testFrozenSnapshotPreventsLaterMutationOfD() {
        let machine = readyMachine(
            assets: [asset("a"), asset("b")],
            conclusions: ["a": .knownBytes(10), "b": .knownBytes(20)]
        )
        guard case .frozen = machine.freezeSubmissionSnapshot() else {
            return XCTFail("应成功冻结快照")
        }

        XCTAssertFalse(machine.removeAsset(identifier: "a"))
        XCTAssertFalse(machine.cancelAll())
        XCTAssertFalse(machine.collectionBecameEmpty())
        XCTAssertEqual(machine.assetIDs, ["a", "b"])
    }

    func testSecondFreezeIsRejectedAndOriginalSnapshotIsKept() {
        let machine = readyMachine(
            assets: [asset("a")],
            conclusions: ["a": .knownBytes(10)]
        )
        guard case let .frozen(first) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("首次应成功冻结")
        }

        XCTAssertEqual(machine.freezeSubmissionSnapshot(), .rejected(.alreadyFrozen))
        XCTAssertEqual(machine.frozenSnapshot, first)
    }

    func testExactly200CompletedAssetsCanBeFrozenWithoutTruncation() {
        let input = makeAssets(count: 200)
        let conclusions = Dictionary(
            uniqueKeysWithValues: input.map { ($0.identifier, AssetScanConclusion.knownBytes(1)) }
        )
        let machine = readyMachine(assets: input, conclusions: conclusions)

        guard case let .frozen(snapshot) = machine.freezeSubmissionSnapshot() else {
            return XCTFail("200 项应允许冻结")
        }

        XCTAssertEqual(snapshot.assetCount, 200)
        XCTAssertEqual(snapshot.assetIDs, input.map(\.identifier))
        XCTAssertEqual(snapshot.knownTotalBytes, 200)
    }

    func testReductionOnlyRemovesAndPreservesOriginalDOrder() {
        let machine = S3StateMachine(assets: makeAssets(count: 201))

        XCTAssertTrue(machine.reduceSelectionTo(assetIDs: ["asset-150", "asset-2", "asset-2"]))

        XCTAssertEqual(machine.assetIDs, ["asset-2", "asset-150"])
        XCTAssertEqual(machine.state, .scanning)
    }

    private func readyMachine(
        assets: [AssetDescriptor],
        conclusions: [String: AssetScanConclusion]
    ) -> S3StateMachine {
        S3StateMachine(
            assets: assets,
            cachedConclusions: conclusions,
            submissionIDGenerator: { "submission" },
            clock: { Date(timeIntervalSince1970: 1) }
        )
    }

    private func asset(_ identifier: String, favorite: Bool = false) -> AssetDescriptor {
        AssetDescriptor(identifier: identifier, isFavorite: favorite)
    }

    private func makeAssets(count: Int) -> [AssetDescriptor] {
        (0..<count).map { asset("asset-\($0)") }
    }
}
