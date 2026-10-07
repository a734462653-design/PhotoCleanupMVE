import Foundation

/// IC-187：「看过档」（SPEC-S1 v12 第二节 `W`、`t_离开`、`看过档`；决策 44、45）。
///
/// 与会话档分开：不随清理会话结束（S5 离开）清档，由协调器持有、经持久层单一写出口写盘。
/// 本卡只负责记与存；已看进度、进入位置与旧档迁移归 S1 重设计批第二张，「新增 N 张」归第三张。
struct S1SeenArchive: Equatable, Sendable {
    /// `W`：在任一入口进入的 S2 里看过的资产——主图停稳、成为当前那一张。只增不减。
    var seenAssetIDs: Set<String> = []
    /// `t_离开[r]`：范围 `r` 的 S2 上次迁出且写回成功的时刻。各范围只写自己的键；虚拟范围也记。
    var leaveTimeByRangeID: [String: Date] = [:]
    /// v11 会话档 `p_范围` 前缀是否已并入 `W`。迁移归 S1 重设计批第二张；本卡只建档，恒为 false。
    var hasMigratedLegacyProgress = false
}

/// 看过档的磁盘形状：版本号、升序标识、自参考日期起的秒数（`Double`，逐位往返）。
/// 版本不符、标识为空或重复即视为坏档（`archive` 为 nil）。
struct PersistedS1SeenArchive: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let seenAssetIDs: [String]
    let leaveTimeByRangeID: [String: Double]
    let hasMigratedLegacyProgress: Bool

    init(_ archive: S1SeenArchive) {
        schemaVersion = Self.currentSchemaVersion
        seenAssetIDs = archive.seenAssetIDs.sorted()
        leaveTimeByRangeID = archive.leaveTimeByRangeID.mapValues { $0.timeIntervalSinceReferenceDate }
        hasMigratedLegacyProgress = archive.hasMigratedLegacyProgress
    }

    var archive: S1SeenArchive? {
        guard schemaVersion == Self.currentSchemaVersion,
              Set(seenAssetIDs).count == seenAssetIDs.count,
              !seenAssetIDs.contains(String()),
              !leaveTimeByRangeID.keys.contains(String()) else {
            return nil
        }
        return S1SeenArchive(
            seenAssetIDs: Set(seenAssetIDs),
            leaveTimeByRangeID: leaveTimeByRangeID.mapValues { Date(timeIntervalSinceReferenceDate: $0) },
            hasMigratedLegacyProgress: hasMigratedLegacyProgress
        )
    }
}
