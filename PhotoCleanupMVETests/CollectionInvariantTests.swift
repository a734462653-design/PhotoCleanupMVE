import Foundation
import Photos
import XCTest
@testable import PhotoCleanupMVE

final class CollectionInvariantTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_786_291_200)

    func testDisjointCompleteClassificationIsAccepted() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: ["资产-C"]
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertTrue(transition.isApplied)
        guard case let .batchFailed(savedCallback) = machine.state else {
            return XCTFail("应保存原始三集合")
        }
        XCTAssertEqual(savedCallback, callback)
    }

    func testSuccessAndFailureOverlapIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-A", "资产-B"],
            unprocessed: ["资产-C"]
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertEqual(transition.rejection, .resultSetsOverlap)
        XCTAssertEqual(machine.state, .submitted)
    }

    func testSuccessAndUnprocessedOverlapIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: ["资产-A", "资产-C"]
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertEqual(transition.rejection, .resultSetsOverlap)
    }

    func testFailureAndUnprocessedOverlapIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: ["资产-B", "资产-C"]
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertEqual(transition.rejection, .resultSetsOverlap)
    }

    func testForeignAssetIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: ["资产-C", "资产-X"]
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertEqual(transition.rejection, .resultSetContainsForeignAsset)
    }

    func testOmittedAssetIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: []
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertEqual(transition.rejection, .resultSetOmitsAsset)
    }

    func testEmptyFailureReasonIsRejected() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: ["资产-C"],
            message: "  \n  "
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertEqual(transition.rejection, .emptyFailureReason)
    }

    func testSuccessResultClassifiesEverySubmittedAssetAsSuccessful() throws {
        var machine = try makeMachine()
        _ = try machine.handle(
            .successCallback(submissionID: makeSnapshot().submissionID, receivedAt: fixedDate),
            persist: ignoreS4Persistence
        )

        guard case let .allSucceeded(result) = machine.state else {
            return XCTFail("应形成成功结果")
        }
        XCTAssertEqual(result.successfulAssetIDs, Set(makeSnapshot().assetIDs))
    }

    func testBatchLevelFailureUsesWholeSubmittedSetAsFailure() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: [],
            failed: Set(makeSnapshot().assetIDs),
            unprocessed: []
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertTrue(transition.isApplied)
        guard case let .batchFailed(saved) = machine.state else {
            return XCTFail("应形成失败结果")
        }
        XCTAssertEqual(saved.failedAssetIDs, Set(makeSnapshot().assetIDs))
        XCTAssertTrue(saved.successfulAssetIDs.isEmpty)
        XCTAssertTrue(saved.unprocessedAssetIDs.isEmpty)
    }

    func testFailureBeforeSystemAcceptanceUsesWholeSubmittedSetAsUnprocessed() throws {
        var machine = try makeMachine()
        let callback = makeCallback(
            successful: [],
            failed: [],
            unprocessed: Set(makeSnapshot().assetIDs)
        )
        let transition = try machine.handle(.failureCallback(callback), persist: ignoreS4Persistence)

        XCTAssertTrue(transition.isApplied)
        guard case let .batchFailed(saved) = machine.state else {
            return XCTFail("应形成失败结果")
        }
        XCTAssertEqual(saved.unprocessedAssetIDs, Set(makeSnapshot().assetIDs))
        XCTAssertTrue(saved.successfulAssetIDs.isEmpty)
        XCTAssertTrue(saved.failedAssetIDs.isEmpty)
    }

    func testFailureEntryReusesPersistedClassificationWithoutModification() throws {
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-B"],
            unprocessed: ["资产-C"]
        )
        let machine = try S5StateMachine.enter(
            from: .failure(
                snapshot: makeSnapshot(),
                callback: callback,
                downstreamTargetState: .failed
            ),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in }
        )

        guard case let .failed(context) = machine.state else {
            return XCTFail("应进入失败状态")
        }
        XCTAssertEqual(context.callback.successfulAssetIDs, callback.successfulAssetIDs)
        XCTAssertEqual(context.callback.failedAssetIDs, callback.failedAssetIDs)
        XCTAssertEqual(context.callback.unprocessedAssetIDs, callback.unprocessedAssetIDs)
    }

    func testUnknownEntryDoesNotConstructClassificationSets() throws {
        let machine = try S5StateMachine.enter(
            from: .unknown(
                snapshot: makeSnapshot(),
                reason: .activeWaitTimedOut,
                downstreamTargetState: .unknown
            ),
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in }
        )

        guard case let .unknown(context) = machine.state else {
            return XCTFail("应进入未知状态")
        }
        XCTAssertEqual(context.snapshot.assetIDs, makeSnapshot().assetIDs)
        XCTAssertEqual(context.reason, .activeWaitTimedOut)
    }

    func testFailureEntryRejectsInvalidClassification() {
        let callback = makeCallback(
            successful: ["资产-A"],
            failed: ["资产-A", "资产-B"],
            unprocessed: ["资产-C"]
        )

        XCTAssertThrowsError(
            try S5StateMachine.enter(
                from: .failure(
                    snapshot: makeSnapshot(),
                    callback: callback,
                    downstreamTargetState: .failed
                ),
                persist: ignoreS5Persistence,
                invalidateOldLists: { _ in }
            )
        ) { error in
            XCTAssertEqual(error as? S5StateMachineError, .invalidFailureHandoff)
        }
    }

    func testPhotoKitUserCancellationClassifiesWholeSetAsUnprocessed() {
        let error = NSError(
            domain: PHPhotosErrorDomain,
            code: PHPhotosError.Code.userCancelled.rawValue,
            userInfo: [NSLocalizedDescriptionKey: "用户取消"]
        )

        let callback = PhotoDeletionService().systemFailureCallback(
            snapshot: makeSnapshot(),
            error: error,
            receivedAt: fixedDate
        )

        XCTAssertTrue(callback.successfulAssetIDs.isEmpty)
        XCTAssertTrue(callback.failedAssetIDs.isEmpty)
        XCTAssertEqual(callback.unprocessedAssetIDs, Set(makeSnapshot().assetIDs))
        XCTAssertEqual(callback.reason.category, .userCancelled)
        XCTAssertEqual(callback.reason.systemDomain, PHPhotosErrorDomain)
        XCTAssertEqual(callback.reason.systemCode, PHPhotosError.Code.userCancelled.rawValue)
    }

    func testS4UserCancellationClassifierRequiresExactDomainAndCode() {
        XCTAssertEqual(
            S4FailureCategory.classify(
                systemDomain: PHPhotosErrorDomain,
                systemCode: 3072
            ),
            .userCancelled
        )
        XCTAssertEqual(
            S4FailureCategory.classify(
                systemDomain: "其他系统域",
                systemCode: 3072
            ),
            .unknown
        )
        XCTAssertEqual(
            S4FailureCategory.classify(
                systemDomain: PHPhotosErrorDomain,
                systemCode: 3073
            ),
            .unknown
        )
    }

    func testPhotoKitBatchFailureClassifiesWholeSetAsFailed() {
        let error = NSError(
            domain: "测试系统域",
            code: 99,
            userInfo: [NSLocalizedDescriptionKey: "整批失败"]
        )

        let callback = PhotoDeletionService().systemFailureCallback(
            snapshot: makeSnapshot(),
            error: error,
            receivedAt: fixedDate
        )

        XCTAssertTrue(callback.successfulAssetIDs.isEmpty)
        XCTAssertEqual(callback.failedAssetIDs, Set(makeSnapshot().assetIDs))
        XCTAssertTrue(callback.unprocessedAssetIDs.isEmpty)
        XCTAssertEqual(callback.reason.category, .unknown)
        XCTAssertEqual(callback.reason.systemDomain, "测试系统域")
        XCTAssertEqual(callback.reason.systemCode, 99)
    }

    private func makeSnapshot() -> SubmissionSnapshot {
        SubmissionSnapshot(
            submissionID: "提交-001",
            assetIDs: ["资产-A", "资产-B", "资产-C"],
            assetCount: 3,
            knownTotalBytes: 3_000,
            unavailableCount: 0,
            volumeDisplayMode: .exact,
            favoriteAssetIDs: ["资产-C"],
            frozenAt: fixedDate
        )
    }

    private func makeCallback(
        successful: Set<String>,
        failed: Set<String>,
        unprocessed: Set<String>,
        message: String = "删除请求未完整执行"
    ) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: makeSnapshot().submissionID,
            successfulAssetIDs: successful,
            failedAssetIDs: failed,
            unprocessedAssetIDs: unprocessed,
            reason: S4FailureReason(
                category: .unknown,
                message: message,
                systemDomain: nil,
                systemCode: nil
            ),
            receivedAt: fixedDate
        )
    }

    private func makeMachine() throws -> S4StateMachine {
        try S4StateMachine.start(
            snapshot: makeSnapshot(),
            claimAndPersist: { state in
                try ignoreS4Persistence(state)
                return true
            }
        )
    }

    private func ignoreS4Persistence(_ state: S4PersistentState) throws {
        _ = state
    }

    private func ignoreS5Persistence(_ state: S5PersistentState) throws {
        _ = state
    }
}
