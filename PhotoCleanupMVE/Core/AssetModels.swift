import Foundation

struct AssetDescriptor: Equatable, Sendable {
    let identifier: String
    let isFavorite: Bool
}

enum AssetScanConclusion: Equatable, Sendable {
    case notStarted
    case inProgress
    case knownBytes(Int64)
    case unavailable

    var isIncomplete: Bool {
        switch self {
        case .notStarted, .inProgress:
            return true
        case .knownBytes, .unavailable:
            return false
        }
    }
}

enum VolumeDisplayMode: Equatable, Sendable {
    case exact
    case lowerBound
}

struct SubmissionSnapshot: Equatable, Sendable {
    let submissionID: String
    let assetIDs: [String]
    let assetCount: Int
    let knownTotalBytes: Int64
    let unavailableCount: Int
    let volumeDisplayMode: VolumeDisplayMode
    let favoriteAssetIDs: Set<String>
    let frozenAt: Date

    init(
        submissionID: String,
        assetIDs: [String],
        assetCount: Int,
        knownTotalBytes: Int64,
        unavailableCount: Int,
        volumeDisplayMode: VolumeDisplayMode,
        favoriteAssetIDs: Set<String>,
        frozenAt: Date
    ) {
        precondition(!assetIDs.isEmpty, "资产标识集合不得为空")
        precondition(Set(assetIDs).count == assetIDs.count, "资产标识必须唯一")
        precondition(assetCount == assetIDs.count, "资产数量必须等于资产标识数量")
        precondition(knownTotalBytes >= 0, "已知总字节数不得为负")
        precondition((0...assetCount).contains(unavailableCount), "不可用数量超出资产数量")
        precondition(
            (volumeDisplayMode == .exact && unavailableCount == 0)
                || (volumeDisplayMode == .lowerBound && unavailableCount > 0),
            "体积显示模式与不可用数量不一致"
        )
        precondition(favoriteAssetIDs.isSubset(of: Set(assetIDs)), "收藏集合必须是资产集合的子集")

        self.submissionID = submissionID
        self.assetIDs = assetIDs
        self.assetCount = assetCount
        self.knownTotalBytes = knownTotalBytes
        self.unavailableCount = unavailableCount
        self.volumeDisplayMode = volumeDisplayMode
        self.favoriteAssetIDs = favoriteAssetIDs
        self.frozenAt = frozenAt
    }
}
