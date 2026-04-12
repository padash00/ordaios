import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct OperatorWidgetTaskSnapshot: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let status: String
    let dueDate: String?
}

struct OperatorWidgetShiftSnapshot: Codable, Hashable {
    let id: String
    let shiftDate: String?
    let shiftTypeLabel: String
    let statusLabel: String
    let location: String?
}

struct OperatorWidgetSnapshot: Codable, Hashable {
    let updatedAt: Date
    let openTasksCount: Int
    let tasks: [OperatorWidgetTaskSnapshot]
    let activeShift: OperatorWidgetShiftSnapshot?

    static let empty = OperatorWidgetSnapshot(
        updatedAt: .distantPast,
        openTasksCount: 0,
        tasks: [],
        activeShift: nil
    )
}

@MainActor
final class OperatorWidgetBridge {
    static let shared = OperatorWidgetBridge()
    private init() {}

    /// Должен совпадать с App Groups в Signing & Capabilities (app + widget).
    private let appGroupSuite = "group.com.padash00.orda.client"
    private let storageKey = "operator.widget.snapshot.v1"

    func syncTasks(_ items: [OperatorTaskItem]) {
        let openStatuses = Set(["new", "todo", "pending", "in_progress", "accepted", "review", "need_info"])
        let openTasks = items.filter { task in
            guard let status = task.status?.lowercased() else { return true }
            return openStatuses.contains(status)
        }

        let top = openTasks.prefix(3).map {
            OperatorWidgetTaskSnapshot(
                id: $0.id,
                title: $0.title,
                status: $0.statusLabel,
                dueDate: $0.dueDate
            )
        }

        var current = loadSnapshot()
        current = OperatorWidgetSnapshot(
            updatedAt: Date(),
            openTasksCount: openTasks.count,
            tasks: Array(top),
            activeShift: current.activeShift
        )
        saveSnapshot(current)
    }

    func syncShift(_ shift: OperatorShiftItem?) {
        var current = loadSnapshot()
        let mapped = shift.map {
            OperatorWidgetShiftSnapshot(
                id: $0.id,
                shiftDate: $0.shiftDate,
                shiftTypeLabel: $0.shiftTypeLabel,
                statusLabel: $0.statusLabel,
                location: $0.location
            )
        }
        current = OperatorWidgetSnapshot(
            updatedAt: Date(),
            openTasksCount: current.openTasksCount,
            tasks: current.tasks,
            activeShift: mapped
        )
        saveSnapshot(current)
    }

    func clear() {
        store.removeObject(forKey: storageKey)
        reloadWidgets()
    }

    private func saveSnapshot(_ snapshot: OperatorWidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        store.set(data, forKey: storageKey)
        reloadWidgets()
    }

    private func loadSnapshot() -> OperatorWidgetSnapshot {
        guard let data = store.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(OperatorWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return decoded
    }

    private var store: UserDefaults {
        UserDefaults(suiteName: appGroupSuite) ?? .standard
    }

    private func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: "OperatorOverviewWidget")
        #endif
    }
}
