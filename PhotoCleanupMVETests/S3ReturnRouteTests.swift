import XCTest
@testable import PhotoCleanupMVE

final class S3ReturnRouteTests: XCTestCase {
    // IC045-001：返回集合为进入集合的真子集时，全部 M[r] 按交集收缩。
    func testIC045_001ProperSubsetShrinksEveryRangeThroughCoordinator() async {
        await MainActor.run {
            var store = makeStore()
            store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
            store.setMarked(true, assetID: "资产-B", rangeID: "范围-月")
            store.setMarked(true, assetID: "资产-B", rangeID: "范围-相册")
            store.setMarked(true, assetID: "资产-C", rangeID: "范围-相册")
            let coordinator = makeCoordinator(store)

            coordinator.removeAsset("资产-A")
            let returned = coordinator.s3Machine?.makeUpstreamReturn()

            XCTAssertEqual(returned?.sourceSessionID, store.sessionID)
            XCTAssertEqual(
                returned?.currentPendingDeletionAssetIDs,
                ["资产-B", "资产-C"]
            )
            coordinator.leaveConfirmation()
            XCTAssertEqual(coordinator.route, .upstream)
            XCTAssertEqual(
                coordinator.sessionStore?
                    .pendingDeletionAssetIDsByRangeID["范围-月"],
                ["资产-B"]
            )
            XCTAssertEqual(
                coordinator.sessionStore?
                    .pendingDeletionAssetIDsByRangeID["范围-相册"],
                ["资产-B", "资产-C"]
            )
            XCTAssertEqual(
                coordinator.sessionStore?.allPendingDeletionAssetIDs,
                ["资产-B", "资产-C"]
            )
        }
    }

    // IC045-002：返回空集时，全部 M[r]、F 与 D_全部 同时清空。
    func testIC045_002EmptyReturnClearsSessionSelections() async {
        await MainActor.run {
            var store = makeStore()
            store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
            store.setMarked(true, assetID: "资产-B", rangeID: "范围-相册")
            let coordinator = makeCoordinator(store)

            coordinator.cancelAllAssets()
            coordinator.leaveConfirmation()

            XCTAssertEqual(coordinator.route, .upstream)
            XCTAssertTrue(
                coordinator.sessionStore?
                    .pendingDeletionAssetIDsByRangeID.values
                    .allSatisfy(\.isEmpty) == true
            )
            XCTAssertTrue(
                coordinator.sessionStore?.firstMarkedRangeIDByAssetID.isEmpty == true
            )
            XCTAssertTrue(
                coordinator.sessionStore?.allPendingDeletionAssetIDs.isEmpty == true
            )
        }
    }

    // IC045-003：用户未移除任何项时，M 与 F 保持逐值不变。
    func testIC045_003UnchangedReturnPreservesMAndF() async {
        await MainActor.run {
            var store = makeStore()
            store.setMarked(true, assetID: "资产-共享", rangeID: "范围-月")
            store.setMarked(true, assetID: "资产-共享", rangeID: "范围-相册")
            store.setMarked(true, assetID: "资产-B", rangeID: "范围-相册")
            let coordinator = makeCoordinator(store)

            coordinator.leaveConfirmation()

            XCTAssertEqual(coordinator.route, .upstream)
            XCTAssertEqual(coordinator.sessionStore, store)
        }
    }

    // IC045-004：来源整理会话标识不匹配时，不更新会话层也不迁出确认页。
    func testIC045_004MismatchedSourceSessionDoesNotUpdateStore() async {
        await MainActor.run {
            var store = makeStore()
            store.setMarked(true, assetID: "资产-A", rangeID: "范围-月")
            let coordinator = makeCoordinator(store)

            XCTAssertFalse(
                coordinator.handleS3Return(
                    S3UpstreamReturn(
                        sourceSessionID: "其他会话",
                        currentPendingDeletionAssetIDs: []
                    )
                )
            )
            XCTAssertEqual(coordinator.route, .confirmation)
            XCTAssertEqual(coordinator.sessionStore, store)
        }
    }

    // IC045-005：同一被移除资产横跨多个范围时，所有相关 M[r] 同步收缩。
    func testIC045_005SharedAssetIsRemovedFromAllRanges() async {
        await MainActor.run {
            var store = makeStore()
            for rangeID in ["范围-月", "范围-年", "范围-相册"] {
                store.setMarked(true, assetID: "资产-共享", rangeID: rangeID)
            }
            store.setMarked(true, assetID: "资产-月独有", rangeID: "范围-月")
            store.setMarked(true, assetID: "资产-年独有", rangeID: "范围-年")
            store.setMarked(true, assetID: "资产-相册独有", rangeID: "范围-相册")
            let coordinator = makeCoordinator(store)

            coordinator.removeAsset("资产-共享")
            coordinator.leaveConfirmation()

            XCTAssertEqual(coordinator.route, .upstream)
            XCTAssertEqual(
                coordinator.sessionStore?
                    .pendingDeletionAssetIDsByRangeID["范围-月"],
                ["资产-月独有"]
            )
            XCTAssertEqual(
                coordinator.sessionStore?
                    .pendingDeletionAssetIDsByRangeID["范围-年"],
                ["资产-年独有"]
            )
            XCTAssertEqual(
                coordinator.sessionStore?
                    .pendingDeletionAssetIDsByRangeID["范围-相册"],
                ["资产-相册独有"]
            )
            XCTAssertNil(
                coordinator.sessionStore?
                    .firstMarkedRangeIDByAssetID["资产-共享"]
            )
            XCTAssertEqual(
                coordinator.sessionStore?.allPendingDeletionAssetIDs,
                ["资产-月独有", "资产-年独有", "资产-相册独有"]
            )
        }
    }

    private func makeStore() -> SessionStore {
        SessionStore(sessionID: "会话-IC045")
    }

    @MainActor
    private func makeCoordinator(_ store: SessionStore) -> CleanupCoordinator {
        let submission = store.makeS3Submission { $0 }
        let descriptors = submission.orderedAssetIDs.map {
            AssetDescriptor(identifier: $0, isFavorite: false)
        }
        let conclusions = Dictionary(
            uniqueKeysWithValues: submission.orderedAssetIDs.map {
                ($0, AssetScanConclusion.knownBytes(1))
            }
        )
        let coordinator = CleanupCoordinator()
        precondition(
            coordinator.enterConfirmation(
                from: submission,
                sessionStore: store,
                descriptors: descriptors,
                cachedConclusions: conclusions
            )
        )
        return coordinator
    }
}
