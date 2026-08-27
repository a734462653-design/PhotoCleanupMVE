import Foundation

/// IC-099b R1（④ Lynn 2026-08-28 定案 2）：S2 **单张资产**占用空间的显示口径。
///
/// 与 S3 的**合计**口径 `DecimalVolumeFormatter` 并存、互不调用、互不影响——
/// S3 的格式与调用点本卡一字未动。差别在于 S2 是单张、会落到 1 MB 以下，
/// 而 S3 是合计、永远落不到那一档。
///
/// 三档，全部**向下截断**，不做四舍五入：
/// - `< 1_000_000` 字节：整数 KB（`byteCount / 1_000`），如 `324 KB`；
/// - `< 1_000_000_000` 字节：一位小数 MB（截断到 0.1），如 `2.4 MB`；
/// - 其余：一位小数 GB（截断到 0.1），如 `25.4 GB`。
///
/// **放置与豁免（IC-101 定案）**：本口径属规格锁定数字格式（v16 决策 35 口径
/// + Decision_log 第 130 条勘误），**不进 String Catalog**——与 S3 十进制截断先例同理。
/// `Scripts/scan-hardcoded-user-visible-strings.ps1` 为本文件加了第二条逐行
/// 规格锁定豁免：路径恰为本文件且字符串值以 ` KB` / ` MB` / ` GB` 结尾者豁免。
/// 因此三处返回的字面量都必须**以字面单位结尾**，单位不得抽成插值参数，
/// 否则该行会被判为残留（IC-101 已实测）。
enum S2AssetVolumeFormatter {
    private static let bytesPerKilobyte: Int64 = 1_000
    private static let bytesPerMegabyte: Int64 = 1_000_000
    private static let bytesPerGigabyte: Int64 = 1_000_000_000

    static func string(forByteCount byteCount: Int64) -> String {
        precondition(byteCount >= 0)

        if byteCount >= bytesPerGigabyte {
            let tenths = truncatedTenths(byteCount, unit: bytesPerGigabyte)
            return "\(tenths / 10).\(tenths % 10) GB"
        }
        if byteCount >= bytesPerMegabyte {
            let tenths = truncatedTenths(byteCount, unit: bytesPerMegabyte)
            return "\(tenths / 10).\(tenths % 10) MB"
        }
        return "\(byteCount / bytesPerKilobyte) KB"
    }

    /// 整数运算求「截断到 0.1」的一位小数，避免浮点在 `999_949_999` 这类
    /// 临界值上向上进位（该值必须显示 `999.9 MB` 而不是 `1000.0 MB`）。
    private static func truncatedTenths(
        _ byteCount: Int64,
        unit: Int64
    ) -> Int64 {
        byteCount / (unit / 10)
    }
}
