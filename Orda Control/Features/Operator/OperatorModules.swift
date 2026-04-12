import Foundation
import Combine
import SwiftUI
import UIKit

protocol OperatorServicing {
    func fetchOverview() async throws -> OperatorOverview
    func fetchShifts(weekStart: String?) async throws -> [OperatorShiftItem]
    func fetchTasks() async throws -> [OperatorTaskItem]
    func respondTask(taskId: String, response: String, note: String?) async throws
    func addTaskComment(taskId: String, content: String) async throws
    func confirmShiftWeek(responseId: String) async throws
    func reportShiftIssue(responseId: String, shiftDate: String, shiftType: String, reason: String) async throws
    func fetchSalary(weekStart: String) async throws -> OperatorSalaryPayload
    func fetchOperatorCabinetProfile() async throws -> OperatorCabinetProfilePayload
    func confirmPointQRLogin(nonce: String) async throws
    func fetchOperatorLead() async throws -> OperatorLeadPayload
    func submitLeadShiftProposal(
        requestId: String,
        proposalAction: String,
        proposalNote: String?,
        replacementOperatorId: String?
    ) async throws
    func updateLeadPointTask(taskId: String, status: String, note: String?) async throws
    func hasOperatorLeadAccess() async -> Bool

    // Shift Manager
    func fetchCurrentPointShift() async throws -> PointCurrentShift?
    func openPointShift(shiftType: String, pointId: String?) async throws
    func closePointShift(operatorId: String, date: String, shiftType: String,
                         cash: Double, kaspi: Double, online: Double, card: Double,
                         comment: String) async throws
    // Arena
    func fetchArenaStations(pointId: String?) async throws -> [ArenaStation]
    func startArenaSession(stationId: String, clientName: String, minutes: Int) async throws
    func stopArenaSession(stationId: String) async throws
    // Personal analytics
    func fetchMyAnalytics(period: String) async throws -> OperatorMyAnalyticsData
}

final class OperatorService: OperatorServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchOverview() async throws -> OperatorOverview {
        let endpoint = APIEndpoint(path: "/api/operator/overview", method: .GET)
        let response: OperatorOverviewEnvelope = try await apiClient.request(endpoint)
        return response.data ?? OperatorOverview(name: nil, shortName: nil, role: nil, stats: nil)
    }

    func fetchShifts(weekStart: String?) async throws -> [OperatorShiftItem] {
        var endpoint = APIEndpoint(path: "/api/operator/shifts", method: .GET)
        if let weekStart, !weekStart.isEmpty {
            endpoint.queryItems = [URLQueryItem(name: "weekStart", value: weekStart)]
        }
        let response: OperatorShiftsEnvelope = try await apiClient.request(endpoint)
        return response.items
    }

    func fetchTasks() async throws -> [OperatorTaskItem] {
        let endpoint = APIEndpoint(path: "/api/operator/tasks", method: .GET)
        let response: OperatorTasksEnvelope = try await apiClient.request(endpoint)
        return response.items
    }

    func respondTask(taskId: String, response: String, note: String?) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/tasks", method: .POST)
        let body = OperatorRespondTaskRequest(action: "respondTask", taskId: taskId, response: response, note: note)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func addTaskComment(taskId: String, content: String) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/tasks", method: .POST)
        let body = OperatorAddCommentRequest(action: "addComment", taskId: taskId, content: content)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func confirmShiftWeek(responseId: String) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/shifts", method: .POST)
        let body = OperatorConfirmWeekRequest(action: "confirmWeek", responseId: responseId)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func reportShiftIssue(responseId: String, shiftDate: String, shiftType: String, reason: String) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/shifts", method: .POST)
        let body = OperatorReportShiftIssueRequest(
            action: "reportIssue",
            responseId: responseId,
            shiftDate: shiftDate,
            shiftType: shiftType,
            reason: reason
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func fetchSalary(weekStart: String) async throws -> OperatorSalaryPayload {
        var endpoint = APIEndpoint(path: "/api/operator/salary", method: .GET)
        endpoint.queryItems = [URLQueryItem(name: "weekStart", value: weekStart)]
        return try await apiClient.request(endpoint)
    }

    func fetchOperatorCabinetProfile() async throws -> OperatorCabinetProfilePayload {
        let endpoint = APIEndpoint(path: "/api/operator/profile", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func confirmPointQRLogin(nonce: String) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/point-qr-confirm", method: .POST)
        let body = OperatorPointQRConfirmBody(nonce: nonce)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func fetchOperatorLead() async throws -> OperatorLeadPayload {
        let endpoint = APIEndpoint(path: "/api/operator/lead", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func submitLeadShiftProposal(
        requestId: String,
        proposalAction: String,
        proposalNote: String?,
        replacementOperatorId: String?
    ) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/lead", method: .POST)
        let body = LeadSubmitProposalBody(
            requestId: requestId,
            proposalAction: proposalAction,
            proposalNote: proposalNote,
            replacementOperatorId: replacementOperatorId
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func updateLeadPointTask(taskId: String, status: String, note: String?) async throws {
        let endpoint = APIEndpoint(path: "/api/operator/lead", method: .POST)
        let body = LeadUpdatePointTaskBody(taskId: taskId, status: status, note: note)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func hasOperatorLeadAccess() async -> Bool {
        do {
            _ = try await fetchOperatorLead()
            return true
        } catch let error as APIError {
            if case .forbidden = error { return false }
            return false
        } catch {
            return false
        }
    }

    // MARK: - Shift Manager

    func fetchCurrentPointShift() async throws -> PointCurrentShift? {
        let endpoint = ContractEndpoint.api_point_shift_report.get
        let response: PointCurrentShiftEnvelope = try await apiClient.request(endpoint)
        return response.data
    }

    func openPointShift(shiftType: String, pointId: String?) async throws {
        let endpoint = ContractEndpoint.api_point_shift_report.post
        let body = OpenShiftBody(action: "openShift", shiftType: shiftType, pointId: pointId)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func closePointShift(operatorId: String, date: String, shiftType: String,
                          cash: Double, kaspi: Double, online: Double, card: Double,
                          comment: String) async throws {
        let endpoint = ContractEndpoint.api_point_shift_report.post
        let body = PointShiftReportPayload(
            payload: PointShiftReportBody(
                date: date,
                operatorId: operatorId,
                shift: shiftType,
                cashAmount: cash,
                kaspiAmount: kaspi,
                onlineAmount: online,
                cardAmount: card,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : comment
            )
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    // MARK: - Arena

    func fetchArenaStations(pointId: String?) async throws -> [ArenaStation] {
        var endpoint = ContractEndpoint.api_point_arena.get
        if let id = pointId { endpoint.queryItems = [URLQueryItem(name: "pointId", value: id)] }
        let response: ArenaEnvelope = try await apiClient.request(endpoint)
        return response.stations ?? []
    }

    func startArenaSession(stationId: String, clientName: String, minutes: Int) async throws {
        let endpoint = ContractEndpoint.api_point_arena.post
        let body = ArenaSessionBody(action: "start", stationId: stationId, clientName: clientName, minutes: minutes)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func stopArenaSession(stationId: String) async throws {
        let endpoint = ContractEndpoint.api_point_arena.post
        let body = ArenaSessionBody(action: "stop", stationId: stationId, clientName: nil, minutes: nil)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    // MARK: - Personal analytics

    func fetchMyAnalytics(period: String) async throws -> OperatorMyAnalyticsData {
        var endpoint = ContractEndpoint.api_operator_analytics.get
        endpoint.queryItems = [URLQueryItem(name: "period", value: period)]
        let response: OperatorMyAnalyticsEnvelope = try await apiClient.request(endpoint)
        return response.data
    }
}

// MARK: - Shift & Arena request bodies

private struct OpenShiftBody: Encodable {
    let action: String
    let shiftType: String
    let pointId: String?
}

private struct ArenaSessionBody: Encodable {
    let action: String
    let stationId: String
    let clientName: String?
    let minutes: Int?
}

// MARK: - Shift / Arena models

struct PointCurrentShift: Decodable {
    let id: String?
    let status: String?        // "open" | "closed" | nil
    let shiftType: String?     // "day" | "night"
    let openedAt: String?
    let cash: Double?
    let kaspi: Double?
    let online: Double?
    let card: Double?
    let comment: String?
    let operatorId: String?
    let pointId: String?
    let pointName: String?

    var isOpen: Bool { status?.lowercased() == "open" }

    var total: Double {
        let c: Double = cash ?? 0
        let k: Double = kaspi ?? 0
        let o: Double = online ?? 0
        let d: Double = card ?? 0
        return c + k + o + d
    }
}

private struct PointCurrentShiftEnvelope: Decodable {
    let data: PointCurrentShift?
}

struct ArenaStation: Decodable, Identifiable {
    let id: String
    let number: Int?
    let name: String?
    let status: String?        // "free" | "busy" | "reserved"
    let sessionStartedAt: String?
    let sessionMinutes: Int?
    let clientName: String?
    let balance: Double?

    var displayName: String { name ?? "Станция \(number ?? 0)" }
    var isFree: Bool { (status ?? "free").lowercased() == "free" }
    var elapsedMinutes: Int? {
        guard let startStr = sessionStartedAt,
              let start = ISO8601DateFormatter().date(from: startStr) else { return nil }
        return Int(Date().timeIntervalSince(start) / 60)
    }
}

private struct ArenaEnvelope: Decodable {
    let stations: [ArenaStation]?
}

struct OperatorMyAnalyticsData: Decodable {
    let tasksCompleted: Int?
    let tasksTotal: Int?
    let shiftsCount: Int?
    let avgRating: Double?
    let rankPosition: Int?
    let rankTotal: Int?
    let netEarnings: Double?
    let weeklyEarnings: [WeeklyEarning]?

    struct WeeklyEarning: Decodable, Identifiable {
        let id: String
        let weekStart: String?
        let amount: Double?
    }
}

private struct OperatorMyAnalyticsEnvelope: Decodable {
    let data: OperatorMyAnalyticsData
}

private struct OperatorRespondTaskRequest: Encodable {
    let action: String
    let taskId: String
    let response: String
    let note: String?
}

private struct OperatorAddCommentRequest: Encodable {
    let action: String
    let taskId: String
    let content: String
}

private struct OperatorConfirmWeekRequest: Encodable {
    let action: String
    let responseId: String
}

private struct OperatorReportShiftIssueRequest: Encodable {
    let action: String
    let responseId: String
    let shiftDate: String
    let shiftType: String
    let reason: String
}

private struct OperatorPointQRConfirmBody: Encodable {
    let nonce: String
}

private struct LeadSubmitProposalBody: Encodable {
    let action: String
    let requestId: String
    let proposalAction: String
    let proposalNote: String?
    let replacementOperatorId: String?

    init(requestId: String, proposalAction: String, proposalNote: String?, replacementOperatorId: String?) {
        self.action = "submitLeadProposal"
        self.requestId = requestId
        self.proposalAction = proposalAction
        self.proposalNote = proposalNote
        self.replacementOperatorId = replacementOperatorId
    }
}

private struct LeadUpdatePointTaskBody: Encodable {
    let action: String
    let taskId: String
    let status: String
    let note: String?

    init(taskId: String, status: String, note: String?) {
        self.action = "updatePointTask"
        self.taskId = taskId
        self.status = status
        self.note = note
    }
}

private struct OperatorOverviewEnvelope: Decodable {
    let data: OperatorOverview?
}

struct OperatorOverview: Decodable {
    let name: String?
    let shortName: String?
    let role: String?
    let stats: OperatorOverviewStats?
}

struct OperatorOverviewStats: Decodable {
    let tasksOpen: Int?
    let tasksDone: Int?
    let shiftsThisWeek: Int?
}

private struct OperatorShiftsEnvelope: Decodable {
    let items: [OperatorShiftItem]

    private enum CodingKeys: String, CodingKey {
        case data
        case responses
        case shifts
    }

    init(from decoder: Decoder) throws {
        if let raw = try? [OperatorShiftItem](from: decoder) {
            items = raw
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([OperatorShiftItem].self, forKey: .responses))
            ?? (try? c.decodeIfPresent([OperatorShiftItem].self, forKey: .shifts))
            ?? (try? c.decodeIfPresent([OperatorShiftItem].self, forKey: .data))
            ?? []
    }
}

struct OperatorShiftItem: Decodable, Identifiable {
    let id: String
    let shiftDate: String?
    let shiftType: String?
    let status: String?
    let operatorName: String?
    let location: String?
    let comment: String?
    let weekStart: String?
    let publishedAt: String?

    private enum CodingKeys: String, CodingKey {
        case id, responseId
        case shiftDate, date
        case shiftType, type
        case status
        case operatorName, operator_name
        case location
        case comment
        case weekStart, week_start
        case publishedAt, published_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id))
            ?? (try? c.decodeIfPresent(String.self, forKey: .responseId))
            ?? UUID().uuidString
        shiftDate = (try? c.decodeIfPresent(String.self, forKey: .shiftDate))
            ?? (try? c.decodeIfPresent(String.self, forKey: .date))
        shiftType = (try? c.decodeIfPresent(String.self, forKey: .shiftType))
            ?? (try? c.decodeIfPresent(String.self, forKey: .type))
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        operatorName = (try? c.decodeIfPresent(String.self, forKey: .operatorName))
            ?? (try? c.decodeIfPresent(String.self, forKey: .operator_name))
        location = try? c.decodeIfPresent(String.self, forKey: .location)
        comment = try? c.decodeIfPresent(String.self, forKey: .comment)
        weekStart = (try? c.decodeIfPresent(String.self, forKey: .weekStart))
            ?? (try? c.decodeIfPresent(String.self, forKey: .week_start))
        publishedAt = (try? c.decodeIfPresent(String.self, forKey: .publishedAt))
            ?? (try? c.decodeIfPresent(String.self, forKey: .published_at))
    }

    var shiftTypeLabel: String {
        switch shiftType?.lowercased() {
        case "night": return "Ночная"
        case "day": return "Дневная"
        default: return shiftType ?? "—"
        }
    }

    var statusLabel: String {
        switch status?.lowercased() {
        case "published": return "Опубликована"
        case "confirmed": return "Подтверждена"
        case "pending": return "Ожидает"
        case "issue", "disputed": return "Проблема"
        case "cancelled": return "Отменена"
        default: return status ?? "—"
        }
    }
}

private struct OperatorTasksEnvelope: Decodable {
    let items: [OperatorTaskItem]

    private enum CodingKeys: String, CodingKey {
        case data
        case tasks
    }

    init(from decoder: Decoder) throws {
        if let raw = try? [OperatorTaskItem](from: decoder) {
            items = raw
            return
        }
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([OperatorTaskItem].self, forKey: .tasks))
            ?? (try? c.decodeIfPresent([OperatorTaskItem].self, forKey: .data))
            ?? []
    }
}

struct OperatorTaskItem: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let status: String?
    let priority: String?
    let dueDate: String?
    let createdAt: String?
    let taskNumber: Int?
    let assignedByName: String?
    let commentsCount: Int?

    private enum CodingKeys: String, CodingKey {
        case id, taskId
        case title, name
        case description
        case status
        case priority
        case dueDate, due_date
        case createdAt, created_at
        case taskNumber, task_number
        case assignedByName, assigned_by_name
        case commentsCount, comments_count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(String.self, forKey: .id))
            ?? (try? c.decodeIfPresent(String.self, forKey: .taskId))
            ?? UUID().uuidString
        title = (try? c.decodeIfPresent(String.self, forKey: .title))
            ?? (try? c.decodeIfPresent(String.self, forKey: .name))
            ?? "Без названия"
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
        priority = try? c.decodeIfPresent(String.self, forKey: .priority)
        dueDate = (try? c.decodeIfPresent(String.self, forKey: .dueDate))
            ?? (try? c.decodeIfPresent(String.self, forKey: .due_date))
        createdAt = (try? c.decodeIfPresent(String.self, forKey: .createdAt))
            ?? (try? c.decodeIfPresent(String.self, forKey: .created_at))
        taskNumber = (try? c.decodeIfPresent(Int.self, forKey: .taskNumber))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .task_number))
        assignedByName = (try? c.decodeIfPresent(String.self, forKey: .assignedByName))
            ?? (try? c.decodeIfPresent(String.self, forKey: .assigned_by_name))
        commentsCount = (try? c.decodeIfPresent(Int.self, forKey: .commentsCount))
            ?? (try? c.decodeIfPresent(Int.self, forKey: .comments_count))
    }

    var statusLabel: String {
        switch status?.lowercased() {
        case "todo": return "К выполнению"
        case "in_progress": return "В работе"
        case "done", "completed": return "Выполнено"
        case "blocked": return "Заблокировано"
        case "review": return "На проверке"
        case "accepted": return "Принято"
        case "need_info": return "Нужно уточнить"
        case "backlog": return "Бэклог"
        default: return status ?? "—"
        }
    }

    var priorityLabel: String {
        switch priority?.lowercased() {
        case "urgent": return "Срочно"
        case "high": return "Высокий"
        case "medium": return "Средний"
        case "low": return "Низкий"
        default: return priority ?? "—"
        }
    }

    var priorityColor: String {
        switch priority?.lowercased() {
        case "urgent", "high": return "error"
        case "medium": return "warning"
        default: return "info"
        }
    }
}

// MARK: - Salary & cabinet (operator API)

enum OperatorISOWeek {
    private static let apiDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func mondayContaining(date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        guard let monday = cal.date(from: comps) else { return apiDayFormatter.string(from: date) }
        return apiDayFormatter.string(from: monday)
    }

    static func shiftMonday(_ iso: String, byWeeks weeks: Int) -> String? {
        guard let d = apiDayFormatter.date(from: iso) else { return nil }
        guard let shifted = Calendar.current.date(byAdding: .day, value: weeks * 7, to: d) else { return nil }
        return mondayContaining(date: shifted)
    }
}

struct OperatorSalaryPayload: Decodable {
    let ok: Bool?
    let operatorInfo: OperatorSalaryOperatorBrief?
    let week: OperatorSalaryWeekPayload?
    let recentWeeks: [OperatorSalaryRecentWeek]?

    private enum CodingKeys: String, CodingKey {
        case ok, week, recentWeeks
        case operatorInfo = "operator"
    }
}

struct OperatorSalaryOperatorBrief: Decodable {
    let id: String?
    let name: String?
    let shortName: String?
}

struct OperatorSalaryWeekPayload: Decodable {
    let id: String?
    let weekStart: String?
    let weekEnd: String?
    let grossAmount: Double?
    let bonusAmount: Double?
    let fineAmount: Double?
    let debtAmount: Double?
    let advanceAmount: Double?
    let netAmount: Double?
    let paidAmount: Double?
    let remainingAmount: Double?
    let status: String?
    let allocations: [OperatorSalaryAllocationRow]?
    let payments: [OperatorSalaryPaymentRow]?
    let adjustments: [OperatorSalaryAdjustmentRow]?
    let debts: [OperatorSalaryDebtRow]?
}

struct OperatorSalaryAllocationRow: Decodable, Identifiable {
    let companyId: String
    let companyName: String?
    let companyCode: String?
    let accruedAmount: Double?
    let netAmount: Double?
    let shareRatio: Double?

    var id: String { companyId }
}

struct OperatorSalaryPaymentRow: Decodable, Identifiable {
    let id: String
    let paymentDate: String?
    let cashAmount: Double?
    let kaspiAmount: Double?
    let totalAmount: Double?
    let comment: String?
    let status: String?
    let createdAt: String?
}

struct OperatorSalaryAdjustmentRow: Decodable, Identifiable {
    let id: String
    let date: String?
    let amount: Double?
    let kind: String?
    let comment: String?
    let companyName: String?
}

struct OperatorSalaryDebtRow: Decodable, Identifiable {
    let id: String
    let amount: Double?
    let comment: String?
    let companyName: String?
    let date: String?
}

struct OperatorSalaryRecentWeek: Decodable, Identifiable {
    let id: String
    let weekStart: String?
    let weekEnd: String?
    let netAmount: Double?
    let paidAmount: Double?
    let remainingAmount: Double?
    let status: String?
    let lastPaymentDate: String?
    let paymentsCount: Int?
}

struct OperatorCabinetProfilePayload: Decodable {
    let ok: Bool?
    let operatorInfo: OperatorCabinetOperatorCard?
    let assignments: [OperatorCabinetCompanyAssignment]?
    let leadAssignments: [OperatorCabinetLeadAssignment]?

    private enum CodingKeys: String, CodingKey {
        case ok, assignments, leadAssignments
        case operatorInfo = "operator"
    }
}

struct OperatorCabinetOperatorCard: Decodable {
    let id: String?
    let name: String?
    let shortName: String?
    let username: String?
    let authRole: String?
    let isActive: Bool?
    let profile: OperatorCabinetProfileFields?
}

struct OperatorCabinetProfileFields: Decodable {
    let fullName: String?
    let photoUrl: String?
    let position: String?
    let phone: String?
    let email: String?
    let hireDate: String?
    let birthDate: String?
    let city: String?
    let about: String?
}

struct OperatorCabinetCompanyAssignment: Decodable, Identifiable {
    let id: String
    let companyId: String?
    let companyName: String?
    let companyCode: String?
    let role: String?
    let isPrimary: Bool?
    let notes: String?
}

struct OperatorCabinetLeadAssignment: Decodable, Identifiable {
    let id: String
    let companyId: String?
    let companyName: String?
    let companyCode: String?
    let role: String?
}

@MainActor
final class OperatorOverviewViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var overview: OperatorOverview?

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            overview = try await service.fetchOverview()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
        }
    }
}

@MainActor
final class OperatorTasksViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var items: [OperatorTaskItem] = []
    @Published var infoMessage: String?

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await service.fetchTasks()
            await TaskSyncManager.shared.syncTasks(items)
            OperatorWidgetBridge.shared.syncTasks(items)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
            OperatorWidgetBridge.shared.syncTasks([])
        }
    }

    func respond(taskId: String, response: String, note: String?) async {
        do {
            try await service.respondTask(taskId: taskId, response: response, note: note)
            infoMessage = "Статус задачи обновлен."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
            AppHaptics.error()
        }
    }

    func comment(taskId: String, content: String) async {
        do {
            try await service.addTaskComment(taskId: taskId, content: content)
            infoMessage = "Комментарий отправлен."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
            AppHaptics.error()
        }
    }
}

@MainActor
final class OperatorShiftsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var items: [OperatorShiftItem] = []
    @Published var infoMessage: String?

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await service.fetchShifts(weekStart: nil)
            let activeShift = activeShiftForLiveActivity()
            await OperatorShiftLiveActivityManager.shared.sync(with: activeShift)
            OperatorWidgetBridge.shared.syncShift(activeShift)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
            await OperatorShiftLiveActivityManager.shared.endCurrent()
            OperatorWidgetBridge.shared.syncShift(nil)
        }
    }

    func confirmWeek(responseId: String) async {
        do {
            try await service.confirmShiftWeek(responseId: responseId)
            infoMessage = "Неделя подтверждена."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
            AppHaptics.error()
        }
    }

    func reportIssue(responseId: String, shiftDate: String, shiftType: String, reason: String) async {
        do {
            try await service.reportShiftIssue(responseId: responseId, shiftDate: shiftDate, shiftType: shiftType, reason: reason)
            infoMessage = "Проблема по смене отправлена."
            AppHaptics.warning()
            await load()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
            AppHaptics.error()
        }
    }

    private func activeShiftForLiveActivity(now: Date = Date()) -> OperatorShiftItem? {
        let activeStatuses = Set(["published", "confirmed", "pending"])
        let candidates = items.filter { item in
            guard let status = item.status?.lowercased() else { return false }
            return activeStatuses.contains(status)
        }

        let ongoing = candidates.filter { isShiftOngoingNow($0, now: now) }
        if let precise = ongoing.sorted(by: shiftSort).first {
            return precise
        }
        return candidates.sorted(by: shiftSort).first
    }

    private func shiftSort(_ lhs: OperatorShiftItem, _ rhs: OperatorShiftItem) -> Bool {
        (lhs.shiftDate ?? "") > (rhs.shiftDate ?? "")
    }

    private func isShiftOngoingNow(_ item: OperatorShiftItem, now: Date) -> Bool {
        guard let shiftDate = item.shiftDate, let baseDate = parseISODate(shiftDate) else { return false }
        let calendar = Calendar(identifier: .gregorian)

        let startHour = item.shiftType?.lowercased() == "night" ? 20 : 8
        let durationHours = 12
        guard let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: baseDate),
              let end = calendar.date(byAdding: .hour, value: durationHours, to: start) else {
            return false
        }

        return now >= start && now <= end
    }

    private func parseISODate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) {
            return date
        }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone.current
        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: String(raw.prefix(10)))
    }
}

@MainActor
final class OperatorSalaryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var payload: OperatorSalaryPayload?
    @Published var weekStartISO: String

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
        weekStartISO = OperatorISOWeek.mondayContaining()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            payload = try await service.fetchSalary(weekStart: weekStartISO)
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
        }
    }

    func shiftWeek(by weeks: Int) async {
        guard let next = OperatorISOWeek.shiftMonday(weekStartISO, byWeeks: weeks) else { return }
        weekStartISO = next
        await load()
    }

    var weeklyNetSeries: [(id: String, label: String, amount: Double)] {
        var rows: [(id: String, weekStart: String, amount: Double)] = []
        let recent = payload?.recentWeeks ?? []
        for w in recent {
            let start = w.weekStart ?? ""
            let id = w.id
            rows.append((id: id, weekStart: start, amount: w.netAmount ?? 0))
        }
        if let week = payload?.week, let start = week.weekStart, !rows.contains(where: { $0.weekStart == start }) {
            rows.append((id: "current-\(start)", weekStart: start, amount: week.netAmount ?? 0))
        }
        return rows
            .sorted { $0.weekStart < $1.weekStart }
            .map { row in
                let label = row.weekStart.split(separator: "-").suffix(2).joined(separator: ".")
                return (id: row.id, label: String(label), amount: row.amount)
            }
    }

    var companyBreakdown: [(id: String, name: String, amount: Double)] {
        guard let allocations = payload?.week?.allocations else { return [] }
        return allocations
            .map { a in
                (
                    id: a.id,
                    name: a.companyName ?? a.companyCode ?? "Компания",
                    amount: max(0, a.netAmount ?? 0)
                )
            }
            .filter { $0.amount > 0.009 }
            .sorted { $0.amount > $1.amount }
    }

    var companyBreakdownTotal: Double {
        companyBreakdown.reduce(0) { $0 + $1.amount }
    }
}

@MainActor
final class OperatorCabinetProfileViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var payload: OperatorCabinetProfilePayload?

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            payload = try await service.fetchOperatorCabinetProfile()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ошибка сети. Повторите попытку."
        }
    }
}

@MainActor
final class OperatorPointQRConfirmViewModel: ObservableObject {
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let service: OperatorServicing

    init(service: OperatorServicing) {
        self.service = service
    }

    func confirm(nonce: String) async {
        let trimmed = nonce.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Введите код из QR."
            return
        }
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        defer { isSubmitting = false }
        do {
            try await service.confirmPointQRLogin(nonce: trimmed)
            successMessage = "Вход на кассе подтверждён."
            AppHaptics.success()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Не удалось подтвердить вход."
            AppHaptics.error()
        }
    }
}
