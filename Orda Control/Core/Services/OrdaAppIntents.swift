import Foundation
import AppIntents

// MARK: - Open Modules Intent

struct OpenSalaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Открыть зарплату"
    static let description = IntentDescription("Открыть раздел Зарплата в Orda Control")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ordaOpenModule, object: "salary")
        return .result()
    }
}

struct OpenTasksIntent: AppIntent {
    static let title: LocalizedStringResource = "Открыть задачи"
    static let description = IntentDescription("Открыть раздел Задачи в Orda Control")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ordaOpenModule, object: "tasks")
        return .result()
    }
}

struct OpenShiftsIntent: AppIntent {
    static let title: LocalizedStringResource = "Открыть смены"
    static let description = IntentDescription("Открыть раздел Смены в Orda Control")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ordaOpenModule, object: "shifts")
        return .result()
    }
}

struct OpenDashboardIntent: AppIntent {
    static let title: LocalizedStringResource = "Главный экран Orda"
    static let description = IntentDescription("Открыть главный экран Orda Control")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .ordaOpenModule, object: "dashboard")
        return .result()
    }
}

// MARK: - Shortcuts Provider

struct OrdaShortcutsProvider: AppShortcutsProvider {
    /// Built with `AppShortcutsBuilder`: list each `AppShortcut` separately (not `[AppShortcut](...)`).
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenDashboardIntent(),
            phrases: ["Открой \(.applicationName)", "Запусти \(.applicationName)"],
            shortTitle: "Главный экран",
            systemImageName: "chart.xyaxis.line"
        )
        AppShortcut(
            intent: OpenSalaryIntent(),
            phrases: ["Зарплата в \(.applicationName)", "Открой зарплату в \(.applicationName)"],
            shortTitle: "Зарплата",
            systemImageName: "banknote.fill"
        )
        AppShortcut(
            intent: OpenTasksIntent(),
            phrases: ["Задачи в \(.applicationName)", "Открой задачи в \(.applicationName)"],
            shortTitle: "Задачи",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: OpenShiftsIntent(),
            phrases: ["Смены в \(.applicationName)", "Открой смены в \(.applicationName)"],
            shortTitle: "Смены",
            systemImageName: "clock.fill"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Used from AppIntents (`perform`) off the main actor; must stay nonisolated.
    nonisolated static let ordaOpenModule = Notification.Name("ordaOpenModule")
}
