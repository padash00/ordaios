import Foundation

enum AuthLoginMapper {
    static let operatorEmailDomain = "operator.local"

    static func normalizeOperatorUsername(_ login: String) -> String {
        login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func toOperatorAuthEmail(_ username: String) -> String {
        "\(normalizeOperatorUsername(username))@\(operatorEmailDomain)"
    }
}
