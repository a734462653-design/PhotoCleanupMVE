import Foundation
@testable import PhotoCleanupMVE

/// IC-188：测试宿主里与真实 Application Support 隔开的持久层。
///
/// 默认 `SessionPersistence()` 写的是测试宿主真实目录；IC-187 起看过档 `s1-seen.json` 也写在那里，IC-188 起
/// S1 的已看进度与进入位置都读它——同一进程里先后运行的协调器测试会互相影响。凡离开 S2（或转入非活跃）的
/// 协调器测试一律用这里的隔离持久层：每次一个新的临时根目录。
enum TestPersistenceIsolation {
    private final class IsolatedFileManager: FileManager {
        private let applicationSupportRoot: URL

        init(applicationSupportRoot: URL) {
            self.applicationSupportRoot = applicationSupportRoot
            super.init()
        }

        override func urls(
            for directory: FileManager.SearchPathDirectory,
            in domainMask: FileManager.SearchPathDomainMask
        ) -> [URL] {
            if directory == .applicationSupportDirectory,
               domainMask.contains(.userDomainMask) {
                return [applicationSupportRoot]
            }
            return super.urls(for: directory, in: domainMask)
        }
    }

    static func makePersistence() -> SessionPersistence {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IC188-isolated-" + UUID().uuidString, isDirectory: true)
        return SessionPersistence(
            fileManager: IsolatedFileManager(applicationSupportRoot: root)
        )
    }
}
