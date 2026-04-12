import Foundation
import EventKit
import UserNotifications
import UIKit

/// Синхронизирует задачи оператора с iOS Календарём и планирует Local Notifications.
/// Вызывается автоматически при каждой загрузке задач.
final class TaskSyncManager {
    static let shared = TaskSyncManager()

    private let eventStore = EKEventStore()
    private let calendarName = "Orda Control"
    private let defaults = UserDefaults.standard

    // UserDefaults keys:
    //   "task_cal_<id>"   → EKEvent.eventIdentifier
    //   "task_notif_<id>" → UNNotificationRequest.identifier

    private init() {}

    // MARK: - Permissions

    func requestPermissions() async {
        // Calendar
        do {
            if #available(iOS 17.0, *) {
                try await eventStore.requestFullAccessToEvents()
            } else {
                try await eventStore.requestAccess(to: .event)
            }
        } catch {}

        // Notifications
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        )
    }

    // MARK: - Sync entry point

    func syncTasks(_ tasks: [OperatorTaskItem]) async {
        let calOk = hasCalendarAccess
        let notifOk = await hasNotificationAccess

        for task in tasks {
            let done = isDone(task)
            if done {
                if calOk  { removeCalendarEvent(for: task.id) }
                if notifOk { removeNotification(for: task.id) }
            } else if let due = task.dueDate, !due.isEmpty {
                if calOk  { upsertCalendarEvent(for: task, dueDateStr: due) }
                if notifOk { scheduleNotificationIfNeeded(for: task, dueDateStr: due) }
            }
        }
    }

    // MARK: - Calendar

    private func upsertCalendarEvent(for task: OperatorTaskItem, dueDateStr: String) {
        let key = calKey(task.id)

        // Already synced and event still lives in the store?
        if let existingId = defaults.string(forKey: key),
           eventStore.event(withIdentifier: existingId) != nil {
            return
        }

        guard let dueDate = parseDate(dueDateStr) else { return }

        let cal = ensureOrdaCalendar()
        let event = EKEvent(eventStore: eventStore)

        let num = task.taskNumber.map { "№\($0) " } ?? ""
        event.title = "📋 \(num)\(task.title)"
        event.notes = task.description.map { ServerJSONPlaintext.normalize($0) }
        event.startDate = dueDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        event.calendar = cal
        // Напоминания: за сутки и за час
        event.alarms = [
            EKAlarm(relativeOffset: -86_400),
            EKAlarm(relativeOffset: -3_600)
        ]

        do {
            try eventStore.save(event, span: .thisEvent, commit: true)
            defaults.set(event.eventIdentifier, forKey: key)
        } catch {}
    }

    private func removeCalendarEvent(for taskId: String) {
        let key = calKey(taskId)
        guard let id = defaults.string(forKey: key),
              let event = eventStore.event(withIdentifier: id) else { return }
        try? eventStore.remove(event, span: .thisEvent, commit: true)
        defaults.removeObject(forKey: key)
    }

    /// Находит или создаёт отдельный календарь «Orda Control».
    private func ensureOrdaCalendar() -> EKCalendar {
        if let existing = eventStore.calendars(for: .event)
            .first(where: { $0.title == calendarName }) {
            return existing
        }

        let cal = EKCalendar(for: .event, eventStore: eventStore)
        cal.title = calendarName
        // Фиолетовый цвет как в AppTheme.accentPrimary (#7C6FF7)
        cal.cgColor = UIColor(red: 0.49, green: 0.44, blue: 0.97, alpha: 1).cgColor

        let source = eventStore.defaultCalendarForNewEvents?.source
            ?? eventStore.sources.first(where: { $0.sourceType == .calDAV })
            ?? eventStore.sources.first(where: { $0.sourceType == .local })
            ?? eventStore.sources.first

        guard let source else { return eventStore.defaultCalendarForNewEvents ?? cal }
        cal.source = source

        do {
            try eventStore.saveCalendar(cal, commit: true)
        } catch {}
        return cal
    }

    // MARK: - Notifications

    private func scheduleNotificationIfNeeded(for task: OperatorTaskItem, dueDateStr: String) {
        let key = notifKey(task.id)
        guard defaults.string(forKey: key) == nil else { return } // уже запланировано

        guard let dueDate = parseDate(dueDateStr),
              let fireDate = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate),
              fireDate > Date()
        else { return }

        let content = UNMutableNotificationContent()
        let num = task.taskNumber.map { "№\($0) " } ?? ""
        content.title = "Задача: \(num)\(task.title)"
        content.body = "Срок: \(ruDate(dueDate))"
        content.sound = .default

        if let assigned = task.assignedByName {
            content.subtitle = "Назначил: \(assigned)"
        }

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let requestId = "orda_task_\(task.id)"

        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: requestId, content: content, trigger: trigger)
        )
        defaults.set(requestId, forKey: key)
    }

    private func removeNotification(for taskId: String) {
        let key = notifKey(taskId)
        guard let id = defaults.string(forKey: key) else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        defaults.removeObject(forKey: key)
    }

    // MARK: - Helpers

    private func isDone(_ task: OperatorTaskItem) -> Bool {
        ["done", "completed"].contains(task.status?.lowercased() ?? "")
    }

    private var hasCalendarAccess: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }

    private var hasNotificationAccess: Bool {
        get async {
            let s = await UNUserNotificationCenter.current().notificationSettings()
            return s.authorizationStatus == .authorized
        }
    }

    private func calKey(_ id: String) -> String { "task_cal_\(id)" }
    private func notifKey(_ id: String) -> String { "task_notif_\(id)" }

    private func parseDate(_ str: String) -> Date? {
        let formats = ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"]
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        for fmt in formats {
            f.dateFormat = fmt
            let trimmed = fmt.contains("Z") ? str : String(str.prefix(fmt.count))
            if let d = f.date(from: trimmed) { return d }
        }
        return nil
    }

    private func ruDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM yyyy, HH:mm"
        return f.string(from: date)
    }
}
