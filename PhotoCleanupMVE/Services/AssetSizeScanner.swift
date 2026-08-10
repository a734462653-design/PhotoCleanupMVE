import Foundation
import Photos

struct AssetSizeScanner {
    func scan(_ asset: PHAsset) async -> AssetScanConclusion {
        let resources = PHAssetResource.assetResources(for: asset)
        guard !resources.isEmpty else {
            return .unavailable
        }

        var total: Int64 = 0
        for resource in resources {
            guard let bytes = await bytes(of: resource) else {
                return .unavailable
            }
            let addition = total.addingReportingOverflow(bytes)
            guard !addition.overflow else {
                return .unavailable
            }
            total = addition.partialValue
        }
        return .knownBytes(total)
    }

    private func bytes(of resource: PHAssetResource) async -> Int64? {
        await withCheckedContinuation { continuation in
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = false
            let accumulator = ByteAccumulator()

            PHAssetResourceManager.default().requestData(
                for: resource,
                options: options,
                dataReceivedHandler: { data in
                    accumulator.append(data.count)
                },
                completionHandler: { error in
                    continuation.resume(
                        returning: error == nil ? accumulator.result : nil
                    )
                }
            )
        }
    }
}
private final class ByteAccumulator {
    private let lock = NSLock()
    private var bytes: Int64 = 0
    private var overflowed = false

    var result: Int64? {
        lock.lock()
        defer { lock.unlock() }
        return overflowed ? nil : bytes
    }

    func append(_ count: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard !overflowed else {
            return
        }
        let addition = bytes.addingReportingOverflow(Int64(count))
        bytes = addition.partialValue
        overflowed = addition.overflow
    }
}
