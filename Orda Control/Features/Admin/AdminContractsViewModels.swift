import Combine
import Foundation
import UIKit

// MARK: - Financial Dashboard ViewModel (mirrors web dashboard)
@MainActor
final class AdminFinanceDashboardViewModel: ObservableObject {

    enum Period: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"
        case quarter = "quarter"

        var label: String {
            switch self {
            case .today: return "Сегодня"
            case .week: return "Неделя"
            case .month: return "Месяц"
            case .quarter: return "Квартал"
            }
        }

        func dateRange() -> (from: String, to: String) {
            let today = Date.todayISO
            switch self {
            case .today:
                return (today, today)
            case .week:
                let from = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
                return (DateFormatter.isoDate.string(from: from), today)
            case .month:
                let from = Calendar.current.date(byAdding: .day, value: -29, to: Date())!
                return (DateFormatter.isoDate.string(from: from), today)
            case .quarter:
                let from = Calendar.current.date(byAdding: .day, value: -89, to: Date())!
                return (DateFormatter.isoDate.string(from: from), today)
            }
        }
    }

    @Published var period: Period = .month
    @Published var incomes: [AdminIncome] = []
    @Published var expenses: [AdminExpense] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let range = period.dateRange()
        do {
            async let inc = service.loadIncomesRange(from: range.from, to: range.to)
            async let exp = service.loadExpensesRange(from: range.from, to: range.to)
            let (i, e) = try await (inc, exp)
            incomes = i
            expenses = e
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    // MARK: - Computed totals
    var totalIncome: Double { incomes.reduce(0) { $0 + incomeTotal($1) } }
    var totalExpense: Double { expenses.reduce(0) { $0 + expenseTotal($1) } }
    var profit: Double { totalIncome - totalExpense }
    var margin: Double { totalIncome > 0 ? (profit / totalIncome) * 100 : 0 }

    var cashIncome: Double { incomes.reduce(0) { $0 + ($1.cashAmount ?? 0) } }
    var kaspiIncome: Double { incomes.reduce(0) { $0 + ($1.kaspiAmount ?? 0) } }
    var cardIncome: Double { incomes.reduce(0) { $0 + ($1.cardAmount ?? 0) } }
    var onlineIncome: Double { incomes.reduce(0) { $0 + ($1.onlineAmount ?? 0) } }

    // MARK: - Daily chart data
    struct DailyPoint: Identifiable {
        let id: String
        let date: String
        let income: Double
        let expense: Double
        let profit: Double
    }

    var dailyChartData: [DailyPoint] {
        var incomeByDay: [String: Double] = [:]
        var expenseByDay: [String: Double] = [:]

        for item in incomes { incomeByDay[item.date, default: 0] += incomeTotal(item) }
        for item in expenses { expenseByDay[item.date, default: 0] += expenseTotal(item) }

        let allDates = Set(incomeByDay.keys).union(expenseByDay.keys).sorted()
        return allDates.map { date in
            let inc = incomeByDay[date, default: 0]
            let exp = expenseByDay[date, default: 0]
            return DailyPoint(id: date, date: date, income: inc, expense: exp, profit: inc - exp)
        }
    }

    // MARK: - Category breakdown
    var categoryBreakdown: [(category: String, amount: Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped
            .map { (category: $0.key, amount: $0.value.reduce(0) { $0 + expenseTotal($1) }) }
            .sorted { $0.amount > $1.amount }
            .prefix(8)
            .map { $0 }
    }

    // MARK: - Status
    var statusText: String {
        if margin > 25 { return "Отлично" }
        if margin > 10 { return "Хорошо" }
        if margin > 0 { return "Внимание" }
        return "Убыток"
    }

    var statusStyle: StatusBadge.Style {
        if margin > 25 { return .excellent }
        if margin > 10 { return .good }
        if margin > 0 { return .warning }
        return .critical
    }

    // MARK: - Helpers
    private func incomeTotal(_ item: AdminIncome) -> Double {
        (item.cashAmount ?? 0) + (item.kaspiAmount ?? 0) + (item.cardAmount ?? 0) + (item.onlineAmount ?? 0)
    }
    private func expenseTotal(_ item: AdminExpense) -> Double {
        (item.cashAmount ?? 0) + (item.kaspiAmount ?? 0)
    }
}

private extension Date {
    static var todayISO: String { DateFormatter.isoDate.string(from: Date()) }
}

private extension DateFormatter {
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

@MainActor
final class AdminListModuleViewModel<Item: Identifiable>: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let loadAction: () async throws -> [Item]

    init(loadAction: @escaping () async throws -> [Item]) {
        self.loadAction = loadAction
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            items = try await loadAction()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func runWrite(action: @escaping () async throws -> Void, successMessage: String) async {
        errorMessage = nil
        infoMessage = nil
        do {
            try await action()
            infoMessage = successMessage
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }
}

@MainActor
final class AdminDashboardModuleViewModel: ObservableObject {
    @Published var dashboard: AdminDashboardPayload = .empty
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            dashboard = try await service.loadDashboard()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}

@MainActor
final class AdminShiftsModuleViewModel: ObservableObject {
    @Published var workflow = AdminShiftWorkflowResponse(ok: true, publications: [], responses: [], requests: [])
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var weekStartISO = Date.adminWeekStartISO

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            workflow = try await service.loadShifts(weekStart: weekStartISO)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func saveShift(payload: ShiftSavePayload) async {
        errorMessage = nil
        do {
            try await service.saveShift(payload)
            infoMessage = "Смена сохранена."
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}

@MainActor
final class AdminOperatorProfileViewModel: ObservableObject {
    @Published var profile: AdminOperatorProfilePayload?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load(operatorId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            profile = try await service.loadOperatorProfile(operatorId: operatorId)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}

@MainActor
final class AdminCustomerHistoryViewModel: ObservableObject {
    @Published var sales: [AdminCustomerSale] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load(customerId: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            sales = try await service.loadCustomerHistory(customerId: customerId)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}

private extension Date {
    static var adminWeekStartISO: String {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let monday = cal.date(from: comps) ?? Date()
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: monday)
    }
}

// MARK: - Salary ViewModel

@MainActor
final class AdminSalaryViewModel: ObservableObject {
    @Published var board: SalaryWeekBoard?
    @Published var rules: SalaryRulesBoard?
    @Published var isLoading = false
    @Published var isActionLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var selectedWeekStart: String = AdminSalaryViewModel.currentWeekMonday()

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    static func currentWeekMonday() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.timeZone = .current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let monday = cal.date(from: comps) ?? Date()
        return f.string(from: monday)
    }

    func shiftWeek(by delta: Int) {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        if let d = f.date(from: selectedWeekStart),
           let next = Calendar.current.date(byAdding: .weekOfYear, value: delta, to: d) {
            selectedWeekStart = f.string(from: next)
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            board = try await service.loadSalaryWeek(weekStart: selectedWeekStart)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func loadRules() async {
        do {
            rules = try await service.loadSalaryRules()
        } catch {
            // Non-critical, ignore
        }
    }

    func createAdjustment(operatorId: String, date: String, amount: Double, kind: String, comment: String?, companyId: String? = nil) async {
        isActionLoading = true
        defer { isActionLoading = false }
        do {
            try await service.createSalaryAdjustment(
                operatorId: operatorId, date: date, amount: amount, kind: kind, comment: comment, companyId: companyId
            )
            infoMessage = adjustmentKindLabel(kind) + " добавлен(а)."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func createPayment(operatorId: String, paymentDate: String, cashAmount: Double?, kaspiAmount: Double?, comment: String?) async {
        isActionLoading = true
        defer { isActionLoading = false }
        do {
            try await service.createSalaryWeeklyPayment(
                operatorId: operatorId,
                weekStart: selectedWeekStart,
                paymentDate: paymentDate,
                cashAmount: cashAmount,
                kaspiAmount: kaspiAmount,
                comment: comment
            )
            infoMessage = "Выплата записана."
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    func voidPayment(paymentId: String, operatorId: String) async {
        do {
            try await service.voidSalaryPayment(
                paymentId: paymentId,
                weekStart: selectedWeekStart,
                operatorId: operatorId
            )
            AppHaptics.success()
            await load()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            AppHaptics.error()
        }
    }

    private func adjustmentKindLabel(_ kind: String) -> String {
        switch kind {
        case "bonus": return "Бонус"
        case "fine": return "Штраф"
        case "debt": return "Долг"
        case "advance": return "Аванс"
        default: return "Корректировка"
        }
    }

    var totals: SalaryWeekTotals? { board?.totals }
    var operators: [SalaryOperatorRow] { board?.operators ?? [] }
    var weekLabel: String {
        guard let board else { return selectedWeekStart }
        return "\(board.weekStart) – \(board.weekEnd)"
    }
}

// MARK: - Profitability ViewModel

@MainActor
final class AdminProfitabilityViewModel: ObservableObject {

    enum Period: String, CaseIterable {
        case month = "month"
        case quarter = "quarter"
        case halfYear = "half_year"
        case year = "year"

        var label: String {
            switch self {
            case .month: return "Месяц"
            case .quarter: return "Квартал"
            case .halfYear: return "Полгода"
            case .year: return "Год"
            }
        }

        func dateRange() -> (from: String, to: String) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            let today = f.string(from: Date())
            let days: Int
            switch self {
            case .month: days = 29
            case .quarter: days = 89
            case .halfYear: days = 179
            case .year: days = 364
            }
            let from = f.string(from: Calendar.current.date(byAdding: .day, value: -days, to: Date())!)
            return (from, today)
        }
    }

    @Published var period: Period = .month
    @Published var data: AdminProfitabilityData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: AdminContractsServicing

    init(service: AdminContractsServicing) {
        self.service = service
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let range = period.dateRange()
        do {
            data = try await service.loadProfitability(from: range.from, to: range.to, includeKaspiDaily: false)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }
}
