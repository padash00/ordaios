import Foundation
import Combine

struct AnalyticsPeriodRange: Equatable {
    var monthStart: String
    var weekStart: String
    var weekEnd: String
    var dateFrom: String
    var dateTo: String

    static var current: AnalyticsPeriodRange {
        let calendar = Calendar(identifier: .iso8601)
        let now = Date()
        let monthStartDate = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let weekStartDate = weekInterval?.start ?? now
        let weekEndDate = calendar.date(byAdding: .day, value: 6, to: weekStartDate) ?? now
        let dateFrom = calendar.date(byAdding: .day, value: -6, to: now) ?? now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return .init(
            monthStart: formatter.string(from: monthStartDate),
            weekStart: formatter.string(from: weekStartDate),
            weekEnd: formatter.string(from: weekEndDate),
            dateFrom: formatter.string(from: dateFrom),
            dateTo: formatter.string(from: now)
        )
    }
}

@MainActor
final class AdminAnalyticsViewModel: ObservableObject {
    @Published var monthly: AdminMonthlyReportData?
    @Published var kpi: AdminKPIDashboardResponse?
    @Published var goals: [GoalItem] = []
    @Published var forecast: ForecastResponse?
    @Published var forecastText = ""
    @Published var weeklyReportText = ""
    @Published var analysisText = ""
    @Published var isLoading = false
    @Published var isActionLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var period: AnalyticsPeriodRange = .current
    @Published var selectedCompanyId: String = ""
    @Published var selectedDayTransactions: AdminDailyTransactionsData?
    @Published var isDayTransactionsLoading = false
    @Published var dayTransactionsError: String?

    private let service: AdminAnalyticsServicing

    init(service: AdminAnalyticsServicing) {
        self.service = service
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let monthDate = period.monthStart.prefix(7).split(separator: "-")
            let year = Int(monthDate.first ?? "") ?? Calendar.current.component(.year, from: Date())
            let month = Int(monthDate.last ?? "") ?? Calendar.current.component(.month, from: Date())

            async let monthlyTask = service.loadMonthlyReport(
                year: year,
                month: month,
                companyId: selectedCompanyId.nonEmpty
            )
            async let kpiTask = service.loadKPIDashboard(
                monthStart: period.monthStart,
                weekStart: period.weekStart,
                weekEnd: period.weekEnd
            )
            async let goalsTask = service.loadGoals(from: period.monthStart, to: period.dateTo)
            async let forecastTask = service.loadForecast()
            async let weeklyTask = service.loadWeeklyReport(dateFrom: period.dateFrom, dateTo: period.dateTo)
            async let analysisTask = service.loadAnalysisAI(for: period)

            monthly = try await monthlyTask
            kpi = try await kpiTask
            goals = try await goalsTask
            let forecastResult = try await forecastTask
            forecast = forecastResult
            forecastText = ServerJSONPlaintext.normalize(forecastResult.text)
            weeklyReportText = ServerJSONPlaintext.normalize((try await weeklyTask).text)
            if let analysisRaw = (try await analysisTask).text,
               !analysisRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                analysisText = ServerJSONPlaintext.normalize(analysisRaw)
            } else {
                analysisText = "Пока нет данных"
            }
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func switchToPreviousWeek() async {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let start = formatter.date(from: period.weekStart) else { return }
        let prevStart = Calendar(identifier: .iso8601).date(byAdding: .day, value: -7, to: start) ?? start
        let prevEnd = Calendar(identifier: .iso8601).date(byAdding: .day, value: 6, to: prevStart) ?? prevStart
        period = AnalyticsPeriodRange(
            monthStart: period.monthStart,
            weekStart: formatter.string(from: prevStart),
            weekEnd: formatter.string(from: prevEnd),
            dateFrom: formatter.string(from: prevStart),
            dateTo: formatter.string(from: prevEnd)
        )
        await loadAll()
    }

    func generatePlans() async {
        isActionLoading = true
        infoMessage = nil
        errorMessage = nil
        defer { isActionLoading = false }
        do {
            try await service.generateKPIPlans(monthStart: period.monthStart)
            infoMessage = "Планы KPI пересчитаны."
            await loadAll()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func upsertGoal(period: String, income: Double, expense: Double, note: String?) async {
        isActionLoading = true
        infoMessage = nil
        errorMessage = nil
        defer { isActionLoading = false }
        do {
            try await service.upsertGoal(.init(period: period, targetIncome: income, targetExpense: expense, note: note?.nonEmpty))
            infoMessage = "Цель сохранена."
            goals = try await service.loadGoals(from: self.period.monthStart, to: self.period.dateTo)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    var kpiTrendPoints: [(String, Double)] {
        guard let rows = kpi?.weekRows else { return [] }
        let grouped = Dictionary(grouping: rows, by: { $0.date })
        return grouped
            .map { date, values in
                let total = values.reduce(0.0) { partial, row in
                    partial + (row.cashAmount ?? 0) + (row.kaspiAmount ?? 0) + (row.cardAmount ?? 0)
                }
                return (date, total)
            }
            .sorted { $0.0 < $1.0 }
    }

    var sortedMonthlyDaily: [AdminMonthlyDailyRow] {
        (monthly?.daily ?? []).sorted { $0.date < $1.date }
    }

    var weekdayShareSorted: [(name: String, share: Double)] {
        guard let map = kpi?.weekdayShare else { return [] }
        return map.map { (name: $0.key, share: $0.value) }.sorted { $0.share > $1.share }
    }

    var forecastWeeklySeries: [(label: String, income: Double, expense: Double)] {
        guard let f = forecast,
              let labels = f.weekLabels,
              let income = f.weeklyIncome,
              let expense = f.weeklyExpense else { return [] }
        let n = min(labels.count, income.count, expense.count)
        guard n > 0 else { return [] }
        return (0..<n).map { i in (labels[i], income[i], expense[i]) }
    }

    func loadDailyTransactions(day: String) async {
        isDayTransactionsLoading = true
        dayTransactionsError = nil
        defer { isDayTransactionsLoading = false }
        do {
            selectedDayTransactions = try await service.loadDailyTransactions(day: day, companyId: selectedCompanyId.nonEmpty)
        } catch {
            dayTransactionsError = APIErrorMapper().map(error: error).errorDescription
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
