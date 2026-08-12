import Foundation

struct FreeDiskSpaceReader {
    func freeDiskStrictGB() -> Double? {
        let rootURL = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        guard let bytes = try? rootURL.resourceValues(
            forKeys: [.volumeAvailableCapacityKey]
        ).volumeAvailableCapacity else {
            return nil
        }
        return Double(bytes) / 1_000_000_000
    }
}
