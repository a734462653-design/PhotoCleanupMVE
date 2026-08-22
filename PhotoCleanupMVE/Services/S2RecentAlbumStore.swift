import Foundation

/// IC-076（v15 回写决策 29、数据定义 `H`）：最近一次成功加入的相簿只保留一个，
/// 跨应用启动持久化于本地。本类型只负责读写，不做存在性校验；校验由协调器在
/// 进入 S2 时用写入服务完成。`H` 不进 `SessionStore`。
protocol S2RecentAlbumStoring {
    func load() -> S2AlbumReference?
    func save(_ album: S2AlbumReference?)
}

struct S2UserDefaultsRecentAlbumStore: S2RecentAlbumStoring {
    /// `UserDefaults` 键名；值为 `[String: String]`，含 `id` 与 `name` 两项。
    static let defaultsKey = "com.iphonephotomanagement.PhotoCleanupMVE.s2.recent-album"
    static let idField = "id"
    static let nameField = "name"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> S2AlbumReference? {
        guard let record = defaults.dictionary(forKey: Self.defaultsKey),
              let id = record[Self.idField] as? String,
              let name = record[Self.nameField] as? String,
              !id.isEmpty else {
            return nil
        }
        return S2AlbumReference(id: id, name: name)
    }

    func save(_ album: S2AlbumReference?) {
        guard let album, !album.id.isEmpty else {
            defaults.removeObject(forKey: Self.defaultsKey)
            return
        }
        defaults.set(
            [Self.idField: album.id, Self.nameField: album.name],
            forKey: Self.defaultsKey
        )
    }
}
