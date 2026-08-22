import Foundation
import XCTest
@testable import PhotoCleanupMVE

final class S2ActionBarWiringTests: XCTestCase {
    // IC-076 G118（R4）：`H` 写入 → 以同一 suite 重建存储 → 读回一致；清除后读回为空。
    func testIC076G118RecentAlbumStoreRoundTripsAndClears() {
        let suiteName = "IC076-recent-album-\(UUID().uuidString)"
        let defaults = tryUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let album = S2AlbumReference(id: "album-076", name: "相簿 076")
        let first = S2UserDefaultsRecentAlbumStore(defaults: defaults)
        XCTAssertNil(first.load())
        first.save(album)
        XCTAssertEqual(first.load(), album)

        let rebuilt = S2UserDefaultsRecentAlbumStore(defaults: defaults)
        XCTAssertEqual(rebuilt.load(), album)
        XCTAssertEqual(
            defaults.dictionary(
                forKey: S2UserDefaultsRecentAlbumStore.defaultsKey
            )?[S2UserDefaultsRecentAlbumStore.idField] as? String,
            "album-076"
        )

        rebuilt.save(nil)
        XCTAssertNil(rebuilt.load())
        XCTAssertNil(
            defaults.object(forKey: S2UserDefaultsRecentAlbumStore.defaultsKey)
        )
        XCTAssertNil(S2UserDefaultsRecentAlbumStore(defaults: defaults).load())

        // 空标识不构成有效 `H`：写入视为清除。
        rebuilt.save(S2AlbumReference(id: "", name: "无效"))
        XCTAssertNil(rebuilt.load())

        let memory = S2InMemoryRecentAlbumStore()
        XCTAssertNil(memory.load())
        memory.save(album)
        XCTAssertEqual(memory.load(), album)
        memory.save(nil)
        XCTAssertNil(memory.load())
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("预期值不应为空", file: file, line: line)
            fatalError("测试无法继续")
        }
        return value
    }
}

/// 测试用内存实现：与 `UserDefaults` 实现遵循同一协议，供协调器断言注入。
final class S2InMemoryRecentAlbumStore: S2RecentAlbumStoring {
    private(set) var stored: S2AlbumReference?
    private(set) var saveCount = 0

    init(initial: S2AlbumReference? = nil) {
        stored = initial
    }

    func load() -> S2AlbumReference? {
        stored
    }

    func save(_ album: S2AlbumReference?) {
        saveCount += 1
        stored = album
    }
}
