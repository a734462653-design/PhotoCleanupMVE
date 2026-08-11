import Foundation

enum L10n {
    static func text(
        _ key: String,
        replacing replacements: [String: String] = [:]
    ) -> String {
        replacements.reduce(NSLocalizedString(key, comment: "")) { text, replacement in
            text.replacingOccurrences(
                of: "{\(replacement.key)}",
                with: replacement.value
            )
        }
    }
}
