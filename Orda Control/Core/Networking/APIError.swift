import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case invalidResponse
    case decodingFailed
    case networkUnavailable
    case timeout
    case unauthorized
    case forbidden
    case validation(message: String)
    case server(message: String)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Некорректный адрес сервера."
        case .invalidResponse:
            return "Некорректный ответ сервера."
        case .decodingFailed:
            return "Ошибка обработки данных сервера."
        case .networkUnavailable:
            return "Ошибка сети. Повторите попытку."
        case .timeout:
            return "Ошибка сети. Повторите попытку."
        case .unauthorized:
            return "Сессия истекла. Войдите снова."
        case .forbidden:
            return "Нет доступа для этой роли."
        case .validation(let message):
            return APIErrorSanitizer.userMessage(for: message, fallback: "Проверьте данные и повторите попытку.")
        case .server(let message):
            return APIErrorSanitizer.userMessage(for: message, fallback: "Ошибка сервера. Повторите позже.")
        case .unknown(let message):
            return APIErrorSanitizer.userMessage(for: message, fallback: "Ошибка сети. Повторите попытку.")
        }
    }
}

struct APIErrorMapper {
    func map(error: Error) -> APIError {
        if let apiError = error as? APIError {
            return apiError
        }

        if error is DecodingError {
            return .decodingFailed
        }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return .networkUnavailable
            case .timedOut:
                return .timeout
            default:
                return .unknown(message: "Ошибка сети: \(urlError.localizedDescription)")
            }
        }

        return .unknown(message: "Неизвестная ошибка: \(error.localizedDescription)")
    }

    func map(statusCode: Int, message: String?) -> APIError {
        let normalized = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            if normalized.contains("missing-point-device-token") {
                return .validation(
                    message: "Point Terminal: нужен токен устройства точки (как у терминала в зале). Обычный вход в приложение для этого раздела не подходит — настройте точку или откройте POS без Point."
                )
            }
            if normalized.contains("invalid-point-device") {
                return .validation(message: "Point Terminal: токен устройства недействителен или точка отключена.")
            }
            if normalized.contains("marketer-shift-read-only") {
                return .validation(message: "Для роли «маркетолог» доступен только просмотр смен.")
            }
            return .forbidden
        case 400...499:
            if normalized.contains("company-id-required") {
                return .validation(
                    message: "Укажите компанию (клуб): на вкладке «Главная» выберите профиль точки, затем повторите действие."
                )
            }
            if normalized.contains("company-not-in-profile") {
                return .validation(
                    message: "Эта компания не привязана к вашему профилю. На главной выберите другую точку и попробуйте снова."
                )
            }
            let trimmed = (message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return .validation(message: "Запрос отклонён сервером. Обновите экран или войдите снова.")
            }
            return .validation(message: APIErrorSanitizer.userMessage(for: message, fallback: "Запрос не выполнен. Попробуйте ещё раз."))
        case 500...599:
            return .server(message: APIErrorSanitizer.userMessage(for: message, fallback: "Ошибка сервера. Повторите позже."))
        default:
            return .unknown(message: APIErrorSanitizer.userMessage(for: message, fallback: "Ошибка сети. Повторите попытку."))
        }
    }
}

private enum APIErrorSanitizer {
    static func userMessage(for raw: String?, fallback: String) -> String {
        guard let raw else { return fallback }
        let text = ServerJSONPlaintext.normalize(raw).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return fallback }
        let lowered = text.lowercased()
        if lowered.contains("row-level security") || lowered.contains("violates row-level security") {
            return "Сервер отклонил сохранение (ограничение доступа). Напишите администратору клуба или попробуйте позже."
        }
        if lowered.contains("client-api-requires-admin-credentials") {
            return "Сервер временно не настроен для клиентских данных. Обратитесь к администратору."
        }
        let forbiddenPatterns = [
            "invalid input syntax for type uuid",
            "syntax error",
            "sqlstate",
            "stack",
            "traceback",
            "unexpected token"
        ]
        if forbiddenPatterns.contains(where: { lowered.contains($0) }) {
            return fallback
        }
        if lowered.hasPrefix("{") || lowered.hasPrefix("[") {
            return fallback
        }
        return text
    }
}
