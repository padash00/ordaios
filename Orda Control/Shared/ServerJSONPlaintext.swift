import Foundation

/// Снимает типичные JSON-обёртки с ответов API, чтобы в UI не показывать сырой JSON.
enum ServerJSONPlaintext {
    static func normalize(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return raw }

        var current = trimmed
        for _ in 0..<6 {
            guard current.hasPrefix("{") || current.hasPrefix("[") else { break }
            guard let data = current.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data)
            else { break }

            guard let extracted = extractHumanText(from: json)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !extracted.isEmpty,
                  extracted != current
            else { break }

            current = extracted
        }

        return current.isEmpty ? raw : current
    }

    private static func extractHumanText(from json: Any) -> String? {
        switch json {
        case let str as String:
            return str
        case let dict as [String: Any]:
            let priority = [
                "text", "message", "error", "detail", "details", "description", "title",
                "summary", "content", "analysis", "report", "body", "answer", "narrative",
                "explanation", "insight", "insights", "reason", "hint", "user_message",
                "userMessage", "msg", "result", "data", "output", "response", "markdown"
            ]
            for key in priority {
                guard let value = dict[key] else { continue }
                if let inner = extractHumanText(from: value), !inner.isEmpty {
                    return inner
                }
            }
            if let errors = dict["errors"] {
                if let inner = extractHumanText(from: errors), !inner.isEmpty {
                    return inner
                }
            }
            if let points = dict["points"] as? [String] {
                return points.filter { !$0.isEmpty }.joined(separator: "\n")
            }
            if let items = dict["items"] as? [String] {
                return items.filter { !$0.isEmpty }.joined(separator: "\n")
            }
            if let bullets = dict["bullets"] as? [String] {
                return bullets.filter { !$0.isEmpty }.joined(separator: "\n")
            }
            return nil
        case let arr as [Any]:
            let parts = arr.compactMap { extractHumanText(from: $0) }.filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: "\n\n")
        default:
            return nil
        }
    }
}
