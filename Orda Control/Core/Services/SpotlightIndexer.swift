import Foundation
import CoreSpotlight
import UIKit

/// Индексирует операторов и задачи в CoreSpotlight для поиска через iOS Spotlight.
final class SpotlightIndexer {
    static let shared = SpotlightIndexer()
    private init() {}

    // MARK: - Operators

    func indexOperators(_ operators: [AdminOperator]) {
        let items = operators.map { op -> CSSearchableItem in
            let attrs = CSSearchableItemAttributeSet(contentType: .contact)
            attrs.title = op.name
            attrs.keywords = [op.name, op.shortName, op.role].compactMap { $0 }
            if let role = op.role { attrs.contentDescription = roleLabel(role) }
            return CSSearchableItem(
                uniqueIdentifier: "orda.operator.\(op.id)",
                domainIdentifier: "com.orda.operators",
                attributeSet: attrs
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    func deindexOperator(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["orda.operator.\(id)"]
        ) { _ in }
    }

    // MARK: - Tasks

    func indexAdminTasks(_ tasks: [AdminTask]) {
        let items = tasks.compactMap { task -> CSSearchableItem? in
            let attrs = CSSearchableItemAttributeSet(contentType: .text)
            attrs.title = task.title
            var keywords = [task.title, task.statusLabel, task.priorityLabel]
            if let desc = task.description { keywords.append(desc) }
            attrs.keywords = keywords
            attrs.contentDescription = "\(task.priorityLabel) · \(task.statusLabel)"
            if let due = task.dueDate {
                attrs.contentCreationDate = ISO8601DateFormatter().date(from: due)
            }
            return CSSearchableItem(
                uniqueIdentifier: "orda.task.\(task.id)",
                domainIdentifier: "com.orda.tasks",
                attributeSet: attrs
            )
        }
        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    func deindexTask(id: String) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: ["orda.task.\(id)"]
        ) { _ in }
    }

    func clearAllAdminTasks() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: ["com.orda.tasks"]
        ) { _ in }
    }

    // MARK: - Helpers

    private func roleLabel(_ role: String) -> String {
        switch role.lowercased() {
        case "operator": return "Оператор"
        case "senior_operator": return "Старший оператор"
        case "cashier": return "Кассир"
        case "manager": return "Менеджер"
        case "admin": return "Администратор"
        default: return role
        }
    }
}
