import Foundation
import Photos

enum PhotoDeletionOutcome {
    case success(receivedAt: Date)
    case failure(S4FailureCallback)
}

struct PhotoDeletionService {
    func delete(snapshot: SubmissionSnapshot) async -> PhotoDeletionOutcome {
        let submitted = Set(snapshot.assetIDs)
        let authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard authorization == .authorized || authorization == .limited else {
            return .failure(
                preflightFailure(
                    snapshot: snapshot,
                    category: .insufficientPermission,
                    message: "照片库权限不足"
                )
            )
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
            return .failure(
                preflightFailure(
                    snapshot: snapshot,
                    category: .assetNotDeletable,
                    message: "提交集合中存在无法取得的资产"
                )
            )
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            } completionHandler: { succeeded, rawError in
                let receivedAt = Date()
                guard !succeeded else {
                    continuation.resume(returning: .success(receivedAt: receivedAt))
                    return
                }

                let error = rawError as NSError?
                let category: S4FailureCategory
                if error?.domain == PHPhotosErrorDomain,
                   error?.code == PHPhotosError.Code.userCancelled.rawValue {
                    category = .userCancelled
                } else {
                    category = .unknown
                }
                let rawMessage = rawError?.localizedDescription
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let message = rawMessage.flatMap { $0.isEmpty ? nil : $0 }
                let callback = S4FailureCallback(
                    submissionID: snapshot.submissionID,
                    successfulAssetIDs: [],
                    failedAssetIDs: submitted,
                    unprocessedAssetIDs: [],
                    reason: S4FailureReason(
                        category: category,
                        message: message ?? "系统未返回失败说明",
                        systemDomain: error?.domain,
                        systemCode: error?.code
                    ),
                    receivedAt: receivedAt
                )
                continuation.resume(returning: .failure(callback))
            }
        }
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
