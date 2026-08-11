import Foundation
import Photos

enum PhotoDeletionOutcome {
    case success(receivedAt: Date)
    case failure(S4FailureCallback)
}

struct PhotoDeletionService {
    func startDeletion(
        snapshot: SubmissionSnapshot,
        completion: @escaping (PhotoDeletionOutcome) -> Void
    ) {
        let submitted = Set(snapshot.assetIDs)
        let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorization == .authorized || authorization == .limited else {
            completion(.failure(
                preflightFailure(
                    snapshot: snapshot,
                    category: .insufficientPermission,
                    message: L10n.text("deletion.failure.insufficient_permission")
                )
            ))
            return
        }

        let fetch = PHAsset.fetchAssets(
            withLocalIdentifiers: snapshot.assetIDs,
            options: nil
        )
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        guard Set(assets.map(\.localIdentifier)) == submitted else {
            completion(.failure(
                preflightFailure(
                    snapshot: snapshot,
                    category: .assetNotDeletable,
                    message: L10n.text("deletion.failure.asset_unavailable")
                )
            ))
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        } completionHandler: { succeeded, rawError in
            let receivedAt = Date()
            guard !succeeded else {
                completion(.success(receivedAt: receivedAt))
                return
            }

            let callback = self.systemFailureCallback(
                snapshot: snapshot,
                error: rawError as NSError?,
                receivedAt: receivedAt
            )
            completion(.failure(callback))
        }
    }

    func systemFailureCallback(
        snapshot: SubmissionSnapshot,
        error: NSError?,
        receivedAt: Date
    ) -> S4FailureCallback {
        let submitted = Set(snapshot.assetIDs)
        let userCancelled = error?.domain == PHPhotosErrorDomain
            && error?.code == PHPhotosError.Code.userCancelled.rawValue
        let category: S4FailureCategory = userCancelled ? .userCancelled : .unknown
        let rawMessage = error?.localizedDescription
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let message = rawMessage.flatMap { $0.isEmpty ? nil : $0 }
        return S4FailureCallback(
            submissionID: snapshot.submissionID,
            successfulAssetIDs: [],
            failedAssetIDs: userCancelled ? [] : submitted,
            unprocessedAssetIDs: userCancelled ? submitted : [],
            reason: S4FailureReason(
                category: category,
                message: message ?? L10n.text("deletion.failure.missing_system_reason"),
                systemDomain: error?.domain,
                systemCode: error?.code
            ),
            receivedAt: receivedAt
        )
    }

    private func preflightFailure(
        snapshot: SubmissionSnapshot,
        category: S4FailureCategory,
        message: String
    ) -> S4FailureCallback {
        S4FailureCallback(
            submissionID: snapshot.submissionID,
            successfulAssetIDs: [],
            failedAssetIDs: [],
            unprocessedAssetIDs: Set(snapshot.assetIDs),
            reason: S4FailureReason(
                category: category,
                message: message,
                systemDomain: nil,
                systemCode: nil
            ),
            receivedAt: Date()
        )
    }
}
