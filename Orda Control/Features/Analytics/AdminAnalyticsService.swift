import Foundation

protocol AdminAnalyticsServicing {
    func loadMonthlyReport(year: Int, month: Int, companyId: String?) async throws -> AdminMonthlyReportData
    func loadKPIDashboard(monthStart: String, weekStart: String, weekEnd: String) async throws -> AdminKPIDashboardResponse
    func generateKPIPlans(monthStart: String) async throws
    func loadGoals(from: String?, to: String?) async throws -> [GoalItem]
    func upsertGoal(_ payload: GoalUpsertRequest) async throws
    func loadForecast() async throws -> ForecastResponse
    func loadWeeklyReport(dateFrom: String, dateTo: String) async throws -> WeeklyReportResponse
    func loadAnalysisAI(for period: AnalyticsPeriodRange) async throws -> AnalysisAIResponse
    func loadDailyTransactions(day: String, companyId: String?) async throws -> AdminDailyTransactionsData
}

final class AdminAnalyticsService: AdminAnalyticsServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadMonthlyReport(year: Int, month: Int, companyId: String?) async throws -> AdminMonthlyReportData {
        var items = [
            URLQueryItem(name: "year", value: "\(year)"),
            URLQueryItem(name: "month", value: "\(month)")
        ]
        if let companyId, !companyId.isEmpty {
            items.append(URLQueryItem(name: "company_id", value: companyId))
        }
        let endpoint = APIEndpoint(path: "/api/admin/reports/monthly", method: .GET, queryItems: items)
        let response: AdminMonthlyReportResponse = try await apiClient.request(endpoint)
        return response.data
    }

    func loadKPIDashboard(monthStart: String, weekStart: String, weekEnd: String) async throws -> AdminKPIDashboardResponse {
        let endpoint = APIEndpoint(
            path: "/api/admin/kpi-dashboard",
            method: .GET,
            queryItems: [
                URLQueryItem(name: "monthStart", value: monthStart),
                URLQueryItem(name: "weekStart", value: weekStart),
                URLQueryItem(name: "weekEnd", value: weekEnd)
            ]
        )
        return try await apiClient.request(endpoint)
    }

    func generateKPIPlans(monthStart: String) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/kpi-dashboard", method: .POST)
        let request = AdminKpiGenerateRequest(action: "generateCollectivePlans", monthStart: monthStart)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: request)
    }

    func loadGoals(from: String?, to: String?) async throws -> [GoalItem] {
        var items: [URLQueryItem] = []
        if let from, !from.isEmpty { items.append(URLQueryItem(name: "from", value: from)) }
        if let to, !to.isEmpty { items.append(URLQueryItem(name: "to", value: to)) }
        let endpoint = APIEndpoint(path: "/api/goals", method: .GET, queryItems: items)
        let response: GoalsEnvelope = try await apiClient.request(endpoint)
        return response.data
    }

    func upsertGoal(_ payload: GoalUpsertRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/goals", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func loadForecast() async throws -> ForecastResponse {
        let endpoint = APIEndpoint(path: "/api/ai/forecast", method: .POST)
        return try await apiClient.request(endpoint, body: EmptyBody())
    }

    func loadWeeklyReport(dateFrom: String, dateTo: String) async throws -> WeeklyReportResponse {
        let endpoint = APIEndpoint(path: "/api/ai/weekly-report", method: .POST)
        let request = WeeklyReportRequest(dateFrom: dateFrom, dateTo: dateTo)
        return try await apiClient.request(endpoint, body: request)
    }

    func loadAnalysisAI(for period: AnalyticsPeriodRange) async throws -> AnalysisAIResponse {
        let endpoint = APIEndpoint(path: "/api/analysis/ai", method: .POST)
        let request = AnalysisAIRequest(
            dataRangeStart: period.dateFrom,
            dataRangeEnd: period.dateTo,
            avgIncome: 0, avgExpense: 0, avgProfit: 0, avgMargin: 0,
            totalIncome: 0, totalExpense: 0, totalCash: 0, totalKaspi: 0, totalCard: 0, totalOnline: 0,
            cashlessShare: 0, onlineShare: 0, predictedIncome: 0, predictedProfit: 0, trend: 0, trendExpense: 0,
            confidenceScore: 0, riskLevel: "medium", seasonalityStrength: 0, growthRate: 0, profitVolatility: 0,
            planIncomeAchievementPct: 0, totalPlanIncome: 0, bestDayName: "—", worstDayName: "—",
            expensesByCategory: [:], anomalies: [],
            currentMonth: .init(income: 0, expense: 0, profit: 0, projectedIncome: 0, projectedProfit: 0),
            previousMonth: .init(income: 0, expense: 0, profit: 0),
            nextMonthForecast: .init(income: 0, profit: 0)
        )
        return try await apiClient.request(endpoint, body: request)
    }

    func loadDailyTransactions(day: String, companyId: String?) async throws -> AdminDailyTransactionsData {
        var items: [URLQueryItem] = [URLQueryItem(name: "day", value: day)]
        if let companyId, !companyId.isEmpty {
            items.append(URLQueryItem(name: "company_id", value: companyId))
        }
        let endpoint = APIEndpoint(path: "/api/admin/reports/monthly", method: .GET, queryItems: items)
        let response: AdminDailyTransactionsResponse = try await apiClient.request(endpoint)
        return response.data
    }
}

private struct EmptyBody: Encodable {}
