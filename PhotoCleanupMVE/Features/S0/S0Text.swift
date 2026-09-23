// IC-165 C（裁定 三）：S0 两页共用的文本 helper，从退役的 S0View／S0CategoryRow／S0CategoryPageView 原样搬出。
import Foundation

/// 字节量文本。SPEC-S0 v1 第十四节第 3 部分末句：字节量一律用系统
/// `ByteCountFormatter` 的 `.file` 口径，不自造单位字样拼接，格式化不进目录。
enum S0ByteCountText {
    static func string(forByteCount byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: max(0, byteCount))
    }
}

/// 类别显示名。取值以 SPEC-S0 v1 第十四节第 3 部分为唯一来源。
enum S0CategoryText {
    static func displayName(for identifier: S0CategoryIdentifier) -> String {
        switch identifier {
        case .bigVideo:
            return L10n.text("s0.category.bigVideo")
        case .screenshot:
            return L10n.text("s0.category.screenshot")
        case .screenRecording:
            return L10n.text("s0.category.screenRecording")
        case .duplicate:
            return L10n.text("s0.category.duplicate")
        case .similar:
            return L10n.text("s0.category.similar")
        }
    }
}

/// 字节量文本的「值 + 单位」拆分。
///
/// `S0ByteCountText` 走系统 `ByteCountFormatter` 的 `.file` 口径（第十四节第 3
/// 部分末句：不自造单位字样拼接），而类别行的登记表把值与单位分了两个字号
/// （`categoryValueFontSize` 24 / `categoryValueUnitFontSize` 12），因此只能
/// 在**呈现层**把格式化结果按最后一个空格拆开。拆不开（本地化输出无空格）时
/// 整串当值、单位为空——不猜、不补。
enum S0ByteCountSplit {
    static func split(_ text: String) -> (value: String, unit: String) {
        guard let separator = text.lastIndex(of: " ") else {
            return (text, "")
        }
        let value = String(text[text.startIndex..<separator])
        let unit = String(text[text.index(after: separator)...])
        return (value, unit)
    }
}

/// IC-156 C：视频时长角标的文本。系统 `DateComponentsFormatter` 的位置式输出（分与秒、
/// 补零），不自拼分隔符、不进目录（裁定 五）。每次现造格式化器，照 `S0ByteCountText`。
enum S0CategoryPageDurationText {
    static func string(for duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: max(0, duration)) ?? String()
    }
}
