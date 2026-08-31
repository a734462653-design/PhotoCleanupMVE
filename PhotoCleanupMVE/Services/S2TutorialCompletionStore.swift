import Foundation

/// IC-110 D：首次引导教程的「已完成/已跳过」持久化（未定项 20，④ 卡内取定）。
///
/// 只存一个布尔：教程是否已经走完或被跳过。**不入 `S2CalibrationConfiguration`**，
/// 因此不是出厂值、`schemaVersion` 不动（同 IC-091 `edgeTolerance`、
/// IC-108 B 探针开关先例）。协议化是为了让状态机断言可注入内存实现，
/// 与 `S2RecentAlbumStoring` 同款。
protocol S2TutorialCompletionStoring {
    func isCompleted() -> Bool
    func markCompleted()
    /// 标定面板「重看教程」用：清掉已完成标记，下次进入 S2 再放一次。
    func reset()
}

struct S2UserDefaultsTutorialCompletionStore: S2TutorialCompletionStoring {
    /// `UserDefaults` 键名；值为 `Bool`。缺失视为「未完成」。
    static let defaultsKey =
        "com.iphonephotomanagement.PhotoCleanupMVE.s2.tutorial-completed"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func isCompleted() -> Bool {
        defaults.bool(forKey: Self.defaultsKey)
    }

    func markCompleted() {
        defaults.set(true, forKey: Self.defaultsKey)
    }

    func reset() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }
}
