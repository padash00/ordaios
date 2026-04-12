import Foundation

enum OnboardingErrorMapper {
    static func message(from error: Error) -> String {
        let mapped = APIErrorMapper().map(error: error)
        let text = mapped.errorDescription ?? ""

        if text.localizedCaseInsensitiveContains("cancelled") || text.contains("canceled") {
            return "Запрос прерван. Повторите попытку."
        }
        if text.contains("email-not-confirmed") || text.contains("email_not_confirmed") {
            return "Подтвердите email по ссылке из письма, затем нажмите «Проверить подтверждение» или войдите снова."
        }
        if text.contains("company-required") || text.contains("default-client-company-not-configured") {
            return "На сервере не настроена компания по умолчанию для клиентов. Обратитесь к администратору (переменная DEFAULT_CLIENT_COMPANY_CODE или одна компания в базе)."
        }
        if text.contains("company-not-found") {
            return "Компания не найдена. Проверьте код компании."
        }
        if text.contains("point-project-not-found") {
            return "Точка не найдена."
        }
        if text.contains("point-project-company-mismatch") {
            return "Эта точка не относится к выбранной компании."
        }
        if text.contains("point-project-without-stations") {
            return "На выбранной точке пока нет активных станций."
        }
        if text.contains("customer-already-exists") {
            return "Клиент с такими данными уже зарегистрирован."
        }
        if mapped == .unauthorized {
            return "Сессия истекла. Войдите снова."
        }
        if mapped == .networkUnavailable || mapped == .timeout {
            return "Ошибка сети. Повторите попытку."
        }
        return text.isEmpty ? "Ошибка сети. Повторите попытку." : text
    }
}
