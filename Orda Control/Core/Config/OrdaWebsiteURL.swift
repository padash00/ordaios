import Foundation

/// Базовый origin веб-панели (совпадает с `API_BASE_URL` без суффикса `/api`).
enum OrdaWebsiteURL {
    static func origin() -> String {
        var s = AppConfig.current.apiBaseURL.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    static func url(path: String) -> URL {
        let p = path.hasPrefix("/") ? path : "/" + path
        let base = origin()
        return URL(string: base + p) ?? AppConfig.current.apiBaseURL
    }
}
