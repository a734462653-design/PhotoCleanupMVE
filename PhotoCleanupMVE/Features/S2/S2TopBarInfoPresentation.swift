import Foundation

// MARK: - IC-099 阶段二 R4：占用空间取数路线

/// 取数路线。按「是否已编辑」先分派，未编辑再按类型分派，**无数值阈值**
/// （④ Decision_log 第 133 条：「占用空间」= **原始资源字节数**）。
enum S2AssetVolumeRoute: String, CaseIterable, Sendable {
    /// 未编辑视频：`requestAVAsset` → `AVURLAsset.url` 文件属性。H43 14/14 逐字节精确。
    case videoAssetURL
    /// 未编辑照片 / LivePhoto：`requestContentEditingInput` → `fullSizeImageURL` 文件属性。
    /// H43 35/35 精确。
    case contentEditingInputURL
    /// 已编辑资产（照片 / LivePhoto / 视频）：**原始**主资源 `requestData` 流式累加。
    ///
    /// 资源选择复用 IC-099b 探针的 `AssetSizeProbeService.primaryResource(in:mediaKind:)`：
    /// 照片与 LivePhoto 取 `.photo`（取不到退 `.fullSizePhoto`），视频取 `.video`
    /// （取不到退 `.fullSizeVideo`）；**LivePhoto 的配对视频不计入**。
    ///
    /// 已编辑资产的 URL 途径读到的是**当前版本**而非原始资源（H43 病理反例
    /// `CCE34A1A`：URL 途径 7,485 B，当前版本 3,899,648 B），与第 133 条的
    /// 「原始资源字节数」语义不符，故一律走资源。该类读取实测 1.6～3.2 ms。
    case originalPrimaryResource
}

/// 路线分派器。六行全覆盖（三类型 × 是否已编辑），纯函数。
enum S2AssetVolumeRouter {
    static func route(
        mediaKind: S2AssetSizeProbeMediaKind,
        isEdited: Bool
    ) -> S2AssetVolumeRoute {
        if isEdited {
            return .originalPrimaryResource
        }
        return mediaKind == .video ? .videoAssetURL : .contentEditingInputURL
    }
}

/// 占用空间取数接口。PhotoKit 实现在 `Services/` 层；失败一律返回 `nil`
/// （`.fullSizePhoto` 缺失、iCloud 不可得、任一路出错都算失败）。
protocol S2AssetVolumeProviding: AnyObject {
    func byteCount(assetID: String) async -> Int64?
}

/// 会话级占用空间缓存与异步取数管线。
///
/// - 每个资产至多取一次数：已解析（成功或失败）与在途中的都不再重复发起（C2）。
/// - 未就绪时对外返回 `nil`，副行只显示序号；**切资产不会读到上一张的值**，
///   因为取值一律按 `assetID` 索引（C3）。
/// - 缓存只在内存，随 S2 的 `S2AssetVolumeStore` 实例（`@StateObject`）释放。
final class S2AssetVolumeStore: ObservableObject {
    /// 已解析的资产：值为 `nil` 表示取数失败，同样不再重复发起。
    @Published private(set) var resolved: [String: Int64?] = [:]

    private var inFlightAssetIDs: Set<String> = []

    /// 已解析的字节数；未就绪或已失败都返回 `nil`（副行退化为只显序号）。
    func byteCount(for assetID: String) -> Int64? {
        guard let value = resolved[assetID] else {
            return nil
        }
        return value
    }

    /// 该资产是否已有结论（成功或失败），用于断言与避免重复取数。
    func isResolved(_ assetID: String) -> Bool {
        resolved[assetID] != nil
    }

    func isInFlight(_ assetID: String) -> Bool {
        inFlightAssetIDs.contains(assetID)
    }

    /// 只在「未解析且不在途」时发起一次取数。
    func requestIfNeeded(
        assetID: String,
        using provider: S2AssetVolumeProviding
    ) {
        guard !assetID.isEmpty,
              !isResolved(assetID),
              !inFlightAssetIDs.contains(assetID) else {
            return
        }
        inFlightAssetIDs.insert(assetID)
        Task { @MainActor [weak self] in
            let byteCount = await provider.byteCount(assetID: assetID)
            guard let self else {
                return
            }
            self.inFlightAssetIDs.remove(assetID)
            // 用 `updateValue` 而不是下标赋值：字典的值类型本身是 `Int64?`，
            // 下标赋值在「值为 nil」时的语义容易被读成删除键，这里要的是
            // **写入一条「已解析且为失败」的记录**，好让后续请求不再重复发起。
            self.resolved.updateValue(byteCount, forKey: assetID)
        }
    }
}

// MARK: - IC-099 阶段二 R1：顶部中部信息区的文本拼装

/// 顶部中部信息区的两行文本（v16 回写决策 35）。纯函数，无副作用。
enum S2TopBarInfoPresentation {
    /// 主行：当前资产拍摄日期。
    ///
    /// - 当年内：`M月d日`；非当年：`yyyy年M月d日`（格式串在 String Catalog 里，
    ///   属规格锁定的显示格式，不由实现自行决定）。
    /// - `creationDate == nil`：返回 `nil`，**主行不显示**（④ 卡内取定，不引入新文案）。
    static func dateText(
        creationDate: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard let creationDate else {
            return nil
        }
        let isSameYear = calendar.component(.year, from: creationDate) ==
            calendar.component(.year, from: now)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = calendar.locale ?? Locale.current
        formatter.timeZone = calendar.timeZone
        // 两个分支各自直接取键：扫描器提取被引用的 key 时，要求键名字面量紧跟在
        // 取文案的调用括号之后；把三元判断写进调用参数里，会让这两个键被判成
        // 「目录里有、产品源码没引用」。
        formatter.dateFormat = isSameYear
            ? L10n.text("s2.top.date_format.current_year")
            : L10n.text("s2.top.date_format.other_year")
        return formatter.string(from: creationDate)
    }

    /// 副行：`{当前序号}/{总数} · {占用空间}`；字节数未就绪或取数失败时退化为
    /// `{当前序号}/{总数}`，**不显示占位符**。
    ///
    /// - `currentIndex` 是从 0 起的索引，显示时 +1。
    static func subtitleText(
        currentIndex: Int,
        totalCount: Int,
        byteCount: Int64?
    ) -> String {
        let position = [
            "current": String(max(0, currentIndex) + 1),
            "total": String(max(0, totalCount))
        ]
        guard let byteCount, byteCount >= 0 else {
            return L10n.text("s2.top.position", replacing: position)
        }
        var replacements = position
        replacements["volume"] = S2AssetVolumeFormatter.string(
            forByteCount: byteCount
        )
        return L10n.text(
            "s2.top.position_with_volume",
            replacing: replacements
        )
    }
}
