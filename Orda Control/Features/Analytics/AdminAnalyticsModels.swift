import Foundation

struct AdminMonthlyReportResponse: Decodable {
    let ok: Bool
    let data: AdminMonthlyReportData
}

struct AdminDailyTransactionsResponse: Decodable {
    let ok: Bool
    let data: AdminDailyTransactionsData
}

struct AdminDailyTransactionsData: Decodable {
    let date: String
    let transactions: [AdminDailyTransaction]
}

struct AdminDailyTransaction: Decodable, Identifiable {
    let id: String
    let saleDate: String
    let totalAmount: Double
    let cashAmount: Double
    let kaspiAmount: Double
    let cardAmount: Double
    let onlineAmount: Double
    let discountAmount: Double
    let loyaltyDiscountAmount: Double

    enum CodingKeys: String, CodingKey {
        case id
        case saleDate = "sale_date"
        case totalAmount = "total_amount"
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case cardAmount = "card_amount"
        case onlineAmount = "online_amount"
        case discountAmount = "discount_amount"
        case loyaltyDiscountAmount = "loyalty_discount_amount"
    }
}

struct AdminMonthlyReportData: Decodable {
    let daily: [AdminMonthlyDailyRow]
    let totals: AdminMonthlyTotals
    let year: Int
    let month: Int
}

struct AdminMonthlyDailyRow: Decodable, Identifiable {
    let date: String
    let count: Int
    let total: Double
    let cash: Double
    let kaspi: Double
    let card: Double
    let online: Double
    let discount: Double

    var id: String { date }
}

struct AdminMonthlyTotals: Decodable {
    let count: Int
    let total: Double
    let cash: Double
    let kaspi: Double
    let card: Double
    let online: Double
    let discount: Double
    let avgCheck: Double

    enum CodingKeys: String, CodingKey {
        case count
        case total
        case cash
        case kaspi
        case card
        case online
        case discount
        case avgCheck
    }
}

struct AdminKPIDashboardResponse: Decodable {
    let collectivePlans: [AdminKPICollectivePlan]
    let weekRows: [AdminKPIIncomeRow]
    let monthRows: [AdminKPIIncomeRow]
    let weekdayShare: [String: Double]
    let operatorNames: [String: String]
}

struct AdminKPICollectivePlan: Decodable, Identifiable {
    let planKey: String
    let monthStart: String
    let companyCode: String?
    let turnoverTargetMonth: Double
    let turnoverTargetWeek: Double
    let isLocked: Bool

    var id: String { planKey }

    enum CodingKeys: String, CodingKey {
        case planKey
        case monthStart
        case companyCode
        case turnoverTargetMonth
        case turnoverTargetWeek
        case isLocked
    }
}

struct AdminKPIIncomeRow: Decodable, Identifiable {
    let date: String
    let cashAmount: Double?
    let kaspiAmount: Double?
    let cardAmount: Double?
    let operatorId: String?

    var id: String { "\(date)-\(operatorId ?? "none")" }
}

struct AdminKpiGenerateRequest: Encodable {
    let action: String
    let monthStart: String
}

struct GoalsEnvelope: Decodable {
    let data: [GoalItem]
    let tableExists: Bool?
}

struct GoalItem: Decodable, Encodable, Identifiable {
    let goalId: String?
    let period: String
    let targetIncome: Double?
    let targetExpense: Double?
    let note: String?

    var id: String { goalId ?? period }

    enum CodingKeys: String, CodingKey {
        case goalId = "id"
        case period
        case targetIncome = "target_income"
        case targetExpense = "target_expense"
        case note
    }
}

struct GoalUpsertRequest: Encodable {
    let period: String
    let targetIncome: Double
    let targetExpense: Double
    let note: String?

    enum CodingKeys: String, CodingKey {
        case period
        case targetIncome = "target_income"
        case targetExpense = "target_expense"
        case note
    }
}

struct ForecastResponse: Decodable {
    let text: String
    let dateFrom: String?
    let dateTo: String?
    let weekLabels: [String]?
    let weeklyIncome: [Double]?
    let weeklyExpense: [Double]?
}

struct WeeklyReportResponse: Decodable {
    let text: String
    let dateFrom: String?
    let dateTo: String?
}

struct WeeklyReportRequest: Encodable {
    let dateFrom: String
    let dateTo: String
}

struct AnalysisAIRequest: Encodable {
    let dataRangeStart: String
    let dataRangeEnd: String
    let avgIncome: Double
    let avgExpense: Double
    let avgProfit: Double
    let avgMargin: Double
    let totalIncome: Double
    let totalExpense: Double
    let totalCash: Double
    let totalKaspi: Double
    let totalCard: Double
    let totalOnline: Double
    let cashlessShare: Double
    let onlineShare: Double
    let predictedIncome: Double
    let predictedProfit: Double
    let trend: Double
    let trendExpense: Double
    let confidenceScore: Double
    let riskLevel: String
    let seasonalityStrength: Double
    let growthRate: Double
    let profitVolatility: Double
    let planIncomeAchievementPct: Double
    let totalPlanIncome: Double
    let bestDayName: String
    let worstDayName: String
    let expensesByCategory: [String: Double]
    let anomalies: [AnalysisAnomaly]
    let currentMonth: AnalysisMonthBlock
    let previousMonth: AnalysisPrevMonthBlock
    let nextMonthForecast: AnalysisNextMonthBlock
}

struct AnalysisAnomaly: Encodable {
    let date: String
    let type: String
    let amount: Double
}

struct AnalysisMonthBlock: Encodable {
    let income: Double
    let expense: Double
    let profit: Double
    let projectedIncome: Double
    let projectedProfit: Double
}

struct AnalysisPrevMonthBlock: Encodable {
    let income: Double
    let expense: Double
    let profit: Double
}

struct AnalysisNextMonthBlock: Encodable {
    let income: Double
    let profit: Double
}

struct AnalysisAIResponse: Decodable {
    let text: String?
    let error: String?
}
