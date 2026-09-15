import Photos
import UIKit

/// IC-148 A（裁定 乙）：S0 氛围底的图源实现——取**照片库中最近一张**。
///
/// 为什么是「最近一张」而不是某个类别的封面：
/// ① 四个态都拿得到（含 S0-1 扫描中与数据尚未出来时），页面一开就有底；
/// ② 与 SPEC-S1 v9「范围封面取按当前排序的第一张」同制，确定性规则、不引入随机；
/// ③ 不依赖类别数据，因而**不被 H68 阻塞**。
///
/// 取不到时回 nil ⟹ 氛围底退化为 `S2AmbientMetrics.baseColor` 纯色。这是
/// `S2AmbientBackdropReadout` 的既有行为（由
/// `testIC146B_AmbientFallsBackToBaseColorWhenLoadFails` 钉住），**本卡不另造回落**。
///
/// 只发**缩略级**请求、禁网络、`deliveryMode` 取 `.fastFormat`：模糊半径 34
/// 之后分辨率没有意义，与 `S2PhotoKitAmbientImageLoader` 同一口径。
final class S0RecentPhotoAmbientLoader: S0AmbientImageProviding {
    /// 排序键。`PHAsset` 的创建时间 keyPath，字符串形式由 PhotoKit 规定。
    private static let creationDateKey = "creationDate"

    private let imageManager: PHImageManager

    init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    func recentAmbientImage() async -> UIImage? {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: Self.creationDateKey, ascending: false)
        ]
        options.fetchLimit = 1
        guard let asset = PHAsset.fetchAssets(
            with: .image,
            options: options
        ).firstObject else {
            return nil
        }
        return await image(for: asset)
    }

    private func image(for asset: PHAsset) async -> UIImage? {
        let requestOptions = PHImageRequestOptions()
        requestOptions.isNetworkAccessAllowed = false
        requestOptions.deliveryMode = .fastFormat
        requestOptions.resizeMode = .fast
        requestOptions.isSynchronous = false
        let edge = S2AmbientMetrics.sourceTargetEdge
        return await withCheckedContinuation { continuation in
            let resumer = S0AmbientContinuationResumer()
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: edge, height: edge),
                contentMode: .aspectFill,
                options: requestOptions
            ) { image, info in
                // `.fastFormat` 也可能先回一张退化图再回终图；只认第一次回调，
                // 多回的一律丢弃（氛围底不需要终图）。与 S2 侧同一处置。
                let isDegraded =
                    (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard image != nil || !isDegraded else {
                    return
                }
                guard resumer.claim() else {
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}

/// 一次性放行闭锁：`requestImage` 的回调可能多回，`CheckedContinuation`
/// 多恢复一次就崩。与 S2 侧同形但**另立一只**——那只是 `private`，跨文件取不到。
private final class S0AmbientContinuationResumer {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else {
            return false
        }
        claimed = true
        return true
    }
}
