import Foundation

enum AppModule: String, CaseIterable, Identifiable {
    case dashboard
    case finance
    case income
    case expense
    case analytics
    case payroll
    case taxes
    case operators
    case shifts
    case tasks
    case clients
    case clientBookings
    case clientSupport
    case inventory
    case store
    case pos
    case pointTerminal
    case settings
    case profile

    var id: String { rawValue }

    var titleRU: String {
        switch self {
        case .dashboard: return "Панель"
        case .finance: return "Финансы"
        case .income: return "Доходы"
        case .expense: return "Расходы"
        case .analytics: return "Аналитика"
        case .payroll: return "Зарплата"
        case .taxes: return "Налоги"
        case .operators: return "Операторы"
        case .shifts: return "Смены"
        case .tasks: return "Задачи"
        case .clients: return "Клиенты"
        case .clientBookings: return "Брони клиентов"
        case .clientSupport: return "Поддержка клиентов"
        case .inventory: return "Склад"
        case .store: return "Магазин"
        case .pos: return "POS"
        case .pointTerminal: return "Point Terminal"
        case .settings: return "Настройки"
        case .profile: return "Профиль"
        }
    }
}

enum ModuleAccessMatrix {
    static func modules(for role: SessionRoleContext?) -> Set<AppModule> {
        guard let role else { return [] }

        if role.isSuperAdmin || (role.persona ?? "").lowercased() == "super_admin" {
            return Set(AppModule.allCases)
        }

        if role.isStaff || (role.persona ?? "").lowercased() == "staff" {
            switch (role.staffRole ?? "").lowercased() {
            case "owner", "manager":
                return [
                    .dashboard, .finance, .income, .expense, .analytics, .payroll, .taxes,
                    .operators, .shifts, .tasks, .clients, .clientBookings, .clientSupport,
                    .inventory, .store, .pos, .pointTerminal,
                    .settings, .profile
                ]
            case "marketer":
                // Без аналитики и финансов: задачи, смены (просмотр), клиенты, поддержка.
                return [
                    .dashboard, .tasks, .shifts, .clients, .clientBookings, .clientSupport, .profile
                ]
            default:
                return [
                    .dashboard, .tasks, .clientSupport, .profile
                ]
            }
        }

        if role.isOperator || (role.persona ?? "").lowercased() == "operator" {
            return [.dashboard, .shifts, .tasks, .operators, .payroll, .profile]
        }

        return []
    }

    static func isVisible(_ module: AppModule, role: SessionRoleContext?) -> Bool {
        modules(for: role).contains(module)
    }
}
