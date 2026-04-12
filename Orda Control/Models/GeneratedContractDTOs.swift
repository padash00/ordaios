import Foundation

// AUTO-GENERATED baseline DTOs from contracts.json scan.

private struct FailableDecodable<Value: Decodable>: Decodable {
    let value: Value?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(Value.self)
    }
}

struct DataListResponse<T: Decodable>: Decodable {
    let data: [T]

    private enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        if let list = try? [FailableDecodable<T>](from: decoder) {
            data = list.compactMap(\.value)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let wrapped = try container.decodeIfPresent([FailableDecodable<T>].self, forKey: .data) ?? []
        data = wrapped.compactMap(\.value)
    }
}

struct AdminIncome: Decodable, Identifiable {
    let id: String
    let date: String
    let companyId: String
    let operatorId: String?
    let shift: String?
    let zone: String?
    let cashAmount: Double?
    let kaspiAmount: Double?
    let kaspiBeforeMidnight: Double?
    let onlineAmount: Double?
    let cardAmount: Double?
    let comment: String?

    // Decoder uses convertFromSnakeCase; CodingKey stringValues must be camelCase (not "cash_amount").
    enum CodingKeys: String, CodingKey {
        case id, date, shift, zone, comment
        case companyId, operatorId
        case cashAmount, kaspiAmount, kaspiBeforeMidnight, onlineAmount, cardAmount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = (try c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        companyId = (try c.decodeIfPresent(String.self, forKey: .companyId)) ?? ""
        operatorId = try c.decodeIfPresent(String.self, forKey: .operatorId)
        shift = try c.decodeIfPresent(String.self, forKey: .shift)
        zone = try c.decodeIfPresent(String.self, forKey: .zone)
        cashAmount = Self.decodeFlexibleDouble(c, key: .cashAmount)
        kaspiAmount = Self.decodeFlexibleDouble(c, key: .kaspiAmount)
        kaspiBeforeMidnight = Self.decodeFlexibleDouble(c, key: .kaspiBeforeMidnight)
        onlineAmount = Self.decodeFlexibleDouble(c, key: .onlineAmount)
        cardAmount = Self.decodeFlexibleDouble(c, key: .cardAmount)
        comment = try c.decodeIfPresent(String.self, forKey: .comment)
    }

    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text)
        }
        return nil
    }

    var shiftLabel: String {
        switch shift?.lowercased() {
        case "day": return "Дневная"
        case "night": return "Ночная"
        case "morning": return "Утренняя"
        case "evening": return "Вечерняя"
        default: return shift ?? "—"
        }
    }

    var total: Double {
        (cashAmount ?? 0) + (kaspiAmount ?? 0) + (onlineAmount ?? 0) + (cardAmount ?? 0)
    }
}

struct AdminExpense: Decodable, Identifiable {
    let id: String
    let date: String
    let companyId: String
    let operatorId: String?
    let category: String
    let cashAmount: Double?
    let kaspiAmount: Double?
    let comment: String?
    let attachmentURL: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case date
        case companyId
        case operatorId
        case category
        case cashAmount
        case kaspiAmount
        case comment
        case attachmentURL
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        id = try c.decode(String.self, forKey: .id)
        date = (try c.decodeIfPresent(String.self, forKey: .date)) ?? ""
        companyId = (try c.decodeIfPresent(String.self, forKey: .companyId)) ?? ""
        operatorId = try c.decodeIfPresent(String.self, forKey: .operatorId)
        let rawCategory = (try c.decodeIfPresent(String.self, forKey: .category))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        category = rawCategory.isEmpty ? "other" : rawCategory
        cashAmount = Self.decodeFlexibleDouble(c, key: .cashAmount)
        kaspiAmount = Self.decodeFlexibleDouble(c, key: .kaspiAmount)
        comment = try c.decodeIfPresent(String.self, forKey: .comment)
        attachmentURL = try c.decodeIfPresent(String.self, forKey: .attachmentURL)
    }

    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text)
        }
        return nil
    }

    var categoryLabel: String {
        switch category.lowercased() {
        case "salary", "payroll": return "Зарплата"
        case "rent", "rental": return "Аренда"
        case "products", "goods", "inventory": return "Товары"
        case "utilities", "utility": return "Коммунальные"
        case "marketing", "advertising": return "Маркетинг"
        case "equipment", "repair": return "Оборудование"
        case "transport", "logistics": return "Транспорт"
        case "taxes", "tax": return "Налоги"
        case "other", "misc": return "Прочее"
        case "food", "consumables": return "Расходники"
        case "cleaning": return "Уборка"
        case "security": return "Охрана"
        default: return category
        }
    }

    var total: Double { (cashAmount ?? 0) + (kaspiAmount ?? 0) }
}

struct AdminTask: Decodable, Identifiable {
    let id: String
    let taskNumber: Int?
    let title: String
    let description: String?
    let status: String
    let priority: String
    let dueDate: String?
    let operatorId: String?
    let companyId: String?
    let createdAt: String?

    var statusLabel: String {
        switch status.lowercased() {
        case "todo": return "К выполнению"
        case "in_progress": return "В работе"
        case "done", "completed": return "Выполнено"
        case "blocked": return "Заблокировано"
        case "review": return "На проверке"
        case "accepted": return "Принято"
        case "need_info": return "Нужно уточнить"
        case "backlog": return "Бэклог"
        default: return status
        }
    }

    var priorityLabel: String {
        switch priority.lowercased() {
        case "urgent": return "Срочно"
        case "high": return "Высокий"
        case "medium": return "Средний"
        case "low": return "Низкий"
        default: return priority
        }
    }

    var statusStyle: StatusBadge.Style {
        switch status.lowercased() {
        case "done", "completed", "accepted": return .excellent
        case "in_progress": return .info
        case "blocked": return .critical
        case "review": return .warning
        default: return .neutral
        }
    }

    var priorityStyle: StatusBadge.Style {
        switch priority.lowercased() {
        case "urgent": return .critical
        case "high": return .warning
        case "medium": return .info
        default: return .neutral
        }
    }
}

struct AdminOperator: Decodable, Identifiable {
    let id: String
    let name: String
    let shortName: String?
    let isActive: Bool?
    let role: String?
    let telegramChatId: String?

    // Decoder uses convertFromSnakeCase; do not map keys to raw snake_case strings.
    private enum CodingKeys: String, CodingKey {
        case id, name, role, shortName, isActive, telegramChatId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try Self.decodeId(c)
        let rawName = (try c.decodeIfPresent(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = rawName.isEmpty ? "Без имени" : rawName
        shortName = try c.decodeIfPresent(String.self, forKey: .shortName)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive)
        role = try c.decodeIfPresent(String.self, forKey: .role)
        telegramChatId = Self.decodeOptionalTelegramChatId(c)
    }

    private static func decodeId(_ c: KeyedDecodingContainer<CodingKeys>) throws -> String {
        if let s = try? c.decode(String.self, forKey: .id) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { return t }
        }
        if let i = try? c.decode(Int.self, forKey: .id) { return String(i) }
        if let d = try? c.decode(Double.self, forKey: .id), d == floor(d), !d.isNaN { return String(Int(d)) }
        throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Missing or invalid operator id")
    }

    /// API may return Telegram chat id as string or JSON number.
    private static func decodeOptionalTelegramChatId(_ c: KeyedDecodingContainer<CodingKeys>) -> String? {
        if (try? c.decodeNil(forKey: .telegramChatId)) == true { return nil }
        if let s = try? c.decode(String.self, forKey: .telegramChatId) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        if let i = try? c.decode(Int.self, forKey: .telegramChatId) { return String(i) }
        if let i = try? c.decode(Int64.self, forKey: .telegramChatId) { return String(i) }
        if let d = try? c.decode(Double.self, forKey: .telegramChatId), d == floor(d) { return String(Int(d)) }
        return nil
    }
}

struct AdminCustomer: Decodable, Identifiable {
    let id: String
    let companyId: String?
    let name: String
    let phone: String?
    let cardNumber: String?
    let email: String?
    let notes: String?
    let loyaltyPoints: Int?
    let totalSpent: Double?
    let visitsCount: Int?
    let isActive: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case companyId
        case name
        case phone
        case cardNumber
        case email
        case notes
        case loyaltyPoints
        case totalSpent
        case visitsCount
        case isActive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        companyId = try container.decodeIfPresent(String.self, forKey: .companyId)
        name = (try container.decodeIfPresent(String.self, forKey: .name)) ?? "Без имени"
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        cardNumber = try container.decodeIfPresent(String.self, forKey: .cardNumber)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        loyaltyPoints = try container.decodeIfPresent(Int.self, forKey: .loyaltyPoints)
        totalSpent = Self.decodeFlexibleDouble(container: container, key: .totalSpent)
        visitsCount = try container.decodeIfPresent(Int.self, forKey: .visitsCount)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive)
    }

    private static func decodeFlexibleDouble(
        container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> Double? {
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let text = try? container.decodeIfPresent(String.self, forKey: key) {
            return Double(text)
        }
        return nil
    }
}

struct AdminCustomerHistoryResponse: Decodable {
    let sales: [AdminCustomerSale]
}

struct AdminCustomerSale: Decodable, Identifiable {
    let id: String
    let saleDate: String?
    let totalAmount: Double?
    let discountAmount: Double?
    let cashAmount: Double?
    let kaspiAmount: Double?
    let cardAmount: Double?
    let onlineAmount: Double?
    let loyaltyPointsEarned: Int?
    let loyaltyPointsSpent: Int?
    let createdAt: String?
}

struct AdminOperatorProfileEnvelope: Decodable {
    let ok: Bool
    let data: AdminOperatorProfilePayload
}

struct AdminOperatorProfilePayload: Decodable {
    let operatorItem: AdminOperator
    let profile: [String: StringCodableValue]?

    private enum CodingKeys: String, CodingKey {
        case operatorItem = "operator"
        case profile
    }
}

struct StringCodableValue: Codable, Hashable {
    let raw: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            raw = string
        } else if let int = try? container.decode(Int.self) {
            raw = String(int)
        } else if let bool = try? container.decode(Bool.self) {
            raw = String(bool)
        } else {
            raw = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

struct AdminShiftWorkflowResponse: Decodable {
    let ok: Bool
    let publications: [ShiftWorkflowItem]?
    let responses: [ShiftWorkflowItem]?
    let requests: [ShiftWorkflowItem]?
}

struct ShiftWorkflowItem: Decodable, Identifiable {
    let id: String
    let date: String?
    let shiftType: String?
    let operatorName: String?
    let status: String?
    let weekStart: String?
}

struct IncomeCreatePayload: Encodable {
    let date: String
    let companyId: String
    let operatorId: String
    let shift: String
    let zone: String?
    let cashAmount: Double
    let kaspiAmount: Double
    let onlineAmount: Double
    let cardAmount: Double
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case date
        case companyId = "company_id"
        case operatorId = "operator_id"
        case shift
        case zone
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case onlineAmount = "online_amount"
        case cardAmount = "card_amount"
        case comment
    }
}

struct AdminIncomeActionRequest: Encodable {
    let action: String
    let payload: IncomeCreatePayload?
    let incomeId: String?
    let onlineAmount: Double?

    enum CodingKeys: String, CodingKey {
        case action
        case payload
        case incomeId
        case onlineAmount = "online_amount"
    }
}

struct ExpenseCreatePayload: Encodable {
    let date: String
    let companyId: String
    let operatorId: String
    let category: String
    let cashAmount: Double
    let kaspiAmount: Double
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case date
        case companyId = "company_id"
        case operatorId = "operator_id"
        case category
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case comment
    }
}

struct AdminExpenseActionRequest: Encodable {
    let action: String
    let payload: ExpenseCreatePayload?
    let expenseId: String?
}

struct ShiftSavePayload: Encodable {
    let companyId: String
    let date: String
    let shiftType: String
    let operatorName: String
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case companyId
        case date
        case shiftType
        case operatorName
        case comment
    }
}

struct AdminShiftActionRequest: Encodable {
    let action: String
    let payload: ShiftSavePayload?
}

struct ShiftBulkAssignWeekPayload: Encodable {
    let companyId: String
    let operatorName: String
    let shiftType: String
    let dates: [String]
}

struct ShiftPublishWeekPayload: Encodable {
    let companyId: String
    let weekStart: String
}

struct ShiftResolveIssuePayload: Encodable {
    let requestId: String
    let status: String
    let resolutionAction: String
    let replacementOperatorName: String?
    let resolutionNote: String?
}

struct AdminShiftBulkAssignWeekRequest: Encodable {
    let action: String
    let payload: ShiftBulkAssignWeekPayload
}

struct AdminShiftPublishWeekRequest: Encodable {
    let action: String
    let payload: ShiftPublishWeekPayload
}

struct AdminShiftResolveIssueRequest: Encodable {
    let action: String
    let payload: ShiftResolveIssuePayload
}

struct TaskCreatePayload: Encodable {
    let title: String
    let description: String?
    let priority: String
    let status: String
    let operatorId: String?
    let companyId: String?
    let dueDate: String?
    let tags: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case priority
        case status
        case operatorId = "operator_id"
        case companyId = "company_id"
        case dueDate = "due_date"
        case tags
    }
}

struct AdminTaskActionRequest: Encodable {
    let action: String
    let payload: TaskCreatePayload?
    let taskId: String?
    let status: String?
    let response: String?
    let note: String?
    let content: String?
    let message: String?

    enum CodingKeys: String, CodingKey {
        case action
        case payload
        case taskId
        case status
        case response
        case note
        case content
        case message
    }
}

struct OperatorCreatePayload: Encodable {
    let name: String
    let fullName: String?
    let shortName: String?
    let position: String?
    let phone: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case shortName = "short_name"
        case position
        case phone
        case email
    }
}

struct AdminOperatorActionRequest: Encodable {
    let action: String
    let payload: OperatorCreatePayload?
    let operatorId: String?
    let isActive: Bool?
    let operatorIds: [String]?
}

struct AdminOperatorProfilePatchRequest: Encodable {
    let operatorId: String
    let profile: [String: String]
    let photoURL: String?
    let telegramChatId: String?

    enum CodingKeys: String, CodingKey {
        case operatorId = "operator_id"
        case profile
        case photoURL = "photo_url"
        case telegramChatId = "telegram_chat_id"
    }
}

struct CustomerCreatePayload: Encodable {
    let name: String
    let phone: String?
    let cardNumber: String?
    let email: String?
    let notes: String?
    let companyId: String?

    enum CodingKeys: String, CodingKey {
        case name
        case phone
        case cardNumber = "card_number"
        case email
        case notes
        case companyId = "company_id"
    }
}

struct AdminCustomerActionRequest: Encodable {
    let action: String
    let payload: CustomerCreatePayload?
    let customerId: String?
    let delta: Int?
}

// MARK: - Salary Models (Weekly)

struct SalaryWeekBoard: Decodable {
    let weekStart: String
    let weekEnd: String
    let operators: [SalaryOperatorRow]
    let totals: SalaryWeekTotals

    enum CodingKeys: String, CodingKey {
        case weekStart, weekEnd, operators, totals
    }
}

struct SalaryOperatorRow: Decodable, Identifiable {
    let id: String
    let name: String
    let shortName: String?
    let isActive: Bool?
    let week: SalaryWeekData

    private enum RootKeys: String, CodingKey {
        case op = "operator"
        case week
    }

    private enum FlatKeys: String, CodingKey {
        case id, name, week, shortName, isActive
    }

    private enum OperatorKeys: String, CodingKey {
        case id, name, shortName, isActive
    }

    init(from decoder: Decoder) throws {
        if let root = try? decoder.container(keyedBy: RootKeys.self), root.contains(.op) {
            let op = try root.nestedContainer(keyedBy: OperatorKeys.self, forKey: .op)
            id = try op.decode(String.self, forKey: .id)
            let rawName = (try op.decodeIfPresent(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            name = rawName.isEmpty ? "Без имени" : rawName
            shortName = try op.decodeIfPresent(String.self, forKey: .shortName)
            isActive = try op.decodeIfPresent(Bool.self, forKey: .isActive)
            week = try root.decode(SalaryWeekData.self, forKey: .week)
            return
        }

        let flat = try decoder.container(keyedBy: FlatKeys.self)
        id = try flat.decode(String.self, forKey: .id)
        let rawName = (try flat.decodeIfPresent(String.self, forKey: .name))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        name = rawName.isEmpty ? "Без имени" : rawName
        shortName = try flat.decodeIfPresent(String.self, forKey: .shortName)
        isActive = try flat.decodeIfPresent(Bool.self, forKey: .isActive)
        week = try flat.decode(SalaryWeekData.self, forKey: .week)
    }
}

struct SalaryWeekData: Decodable {
    let id: String
    let grossAmount: Double
    let bonusAmount: Double
    let fineAmount: Double
    let debtAmount: Double
    let advanceAmount: Double
    let netAmount: Double
    let paidAmount: Double
    let remainingAmount: Double
    let status: String
    let payments: [SalaryPayment]
    let allocations: [SalaryAllocation]

    enum CodingKeys: String, CodingKey {
        case id, status, payments, allocations, companyAllocations
        case grossAmount, bonusAmount, fineAmount, debtAmount
        case advanceAmount, netAmount, paidAmount, remainingAmount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        grossAmount = try SalaryWeekData.decodeMoney(c, key: .grossAmount)
        bonusAmount = try SalaryWeekData.decodeMoney(c, key: .bonusAmount)
        fineAmount = try SalaryWeekData.decodeMoney(c, key: .fineAmount)
        debtAmount = try SalaryWeekData.decodeMoney(c, key: .debtAmount)
        advanceAmount = try SalaryWeekData.decodeMoney(c, key: .advanceAmount)
        netAmount = try SalaryWeekData.decodeMoney(c, key: .netAmount)
        paidAmount = try SalaryWeekData.decodeMoney(c, key: .paidAmount)
        remainingAmount = try SalaryWeekData.decodeMoney(c, key: .remainingAmount)
        status = try c.decode(String.self, forKey: .status)
        payments = try c.decodeIfPresent([SalaryPayment].self, forKey: .payments) ?? []
        if let list = try c.decodeIfPresent([SalaryAllocation].self, forKey: .allocations) {
            allocations = list
        } else if let list = try c.decodeIfPresent([SalaryAllocation].self, forKey: .companyAllocations) {
            allocations = list
        } else {
            allocations = []
        }
    }

    private static func decodeMoney(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) throws -> Double {
        if let v = try c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try c.decodeIfPresent(String.self, forKey: key), let v = Double(s) { return v }
        return 0
    }
}

struct SalaryPayment: Decodable, Identifiable {
    let id: String
    let paymentDate: String
    let cashAmount: Double
    let kaspiAmount: Double
    let totalAmount: Double
    let comment: String?
    let status: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, comment, status, paymentDate, cashAmount, kaspiAmount, totalAmount, createdAt
    }
}

struct SalaryAllocation: Decodable {
    let companyId: String
    let companyCode: String?
    let companyName: String?
    let accruedAmount: Double
    let bonusAmount: Double
    let fineAmount: Double
    let debtAmount: Double
    let advanceAmount: Double
    let netAmount: Double
    let shareRatio: Double

    enum CodingKeys: String, CodingKey {
        case companyId, companyCode, companyName
        case accruedAmount, bonusAmount, fineAmount, debtAmount
        case advanceAmount, netAmount, shareRatio
    }
}

struct SalaryWeekTotals: Decodable {
    let grossAmount: Double
    let bonusAmount: Double
    let fineAmount: Double
    let debtAmount: Double
    let advanceAmount: Double
    let netAmount: Double
    let paidAmount: Double
    let remainingAmount: Double
    let paidOperators: Int
    let partialOperators: Int
    let activeOperators: Int
    let totalOperators: Int
}

// MARK: Salary Mutations

struct SalaryActionBody<P: Encodable>: Encodable {
    let action: String
    let payload: P
}

struct SalaryAdjustmentData: Encodable {
    let operatorId: String
    let date: String
    let amount: Double
    let kind: String
    let comment: String?
    let companyId: String?

    enum CodingKeys: String, CodingKey {
        case operatorId = "operator_id"
        case date, amount, kind, comment
        case companyId = "company_id"
    }
}

struct SalaryWeeklyPaymentData: Encodable {
    let operatorId: String
    let weekStart: String
    let paymentDate: String
    let cashAmount: Double?
    let kaspiAmount: Double?
    let comment: String?

    enum CodingKeys: String, CodingKey {
        case operatorId = "operator_id"
        case weekStart = "week_start"
        case paymentDate = "payment_date"
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case comment
    }
}

struct SalaryVoidPaymentData: Encodable {
    let paymentId: String
    let weekStart: String
    let operatorId: String

    enum CodingKeys: String, CodingKey {
        case paymentId, weekStart, operatorId
    }
}

// MARK: Salary Rules

struct SalaryRulesBoard: Decodable {
    let rules: [SalaryRuleItem]
    let companies: [SalaryCompanyItem]
}

struct SalaryRuleItem: Decodable, Identifiable {
    let id: Int
    let companyCode: String
    let shiftType: String
    let basePerShift: Double?
    let seniorOperatorBonus: Double?
    let seniorCashierBonus: Double?
    let threshold1Turnover: Double?
    let threshold1Bonus: Double?
    let threshold2Turnover: Double?
    let threshold2Bonus: Double?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id, companyCode, shiftType, basePerShift
        case seniorOperatorBonus, seniorCashierBonus
        case threshold1Turnover, threshold1Bonus, threshold2Turnover, threshold2Bonus
        case isActive
    }
}

struct SalaryCompanyItem: Decodable, Identifiable {
    let id: String
    let name: String
    let code: String?

    enum CodingKeys: String, CodingKey {
        case id, name, code
    }
}

// MARK: - Profitability / P&L Models

struct AdminProfitabilityData: Decodable {
    let revenue: Double?
    let costOfGoods: Double?
    let grossProfit: Double?
    let grossMargin: Double?
    let operatingExpenses: Double?
    let ebitda: Double?
    let netProfit: Double?
    let netMargin: Double?
    let period: String?
    let breakdown: [ProfitabilityLine]?

    enum CodingKeys: String, CodingKey {
        case revenue, costOfGoods, grossProfit, grossMargin, operatingExpenses
        case ebitda, netProfit, netMargin, period, breakdown
    }
}

struct ProfitabilityLine: Decodable, Identifiable {
    let id: String
    let label: String
    let amount: Double?
    let type: String?
}

// MARK: - Company Models

struct AdminCompany: Decodable, Identifiable {
    let id: String
    let name: String
    let code: String?
}

// MARK: - Inventory Models

struct InventoryOverview: Decodable {
    let categories: [InventoryCategory]
    let suppliers: [InventorySupplier]
    let items: [InventoryItem]
    let locations: [InventoryLocation]
    let stock: [InventoryStockRow]
}

struct InventoryCategory: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String?
}

struct InventorySupplier: Decodable, Identifiable {
    let id: String
    let name: String
    let contactName: String?
    let phone: String?
    let notes: String?
    enum CodingKeys: String, CodingKey {
        case id, name, phone, notes
        case contactName = "contact_name"
    }
}

struct InventoryItem: Decodable, Identifiable {
    let id: String
    let name: String
    let barcode: String?
    let categoryId: String?
    let salePrice: Double?
    let defaultPurchasePrice: Double?
    let unit: String?
    let notes: String?
    let itemType: String?
    let lowStockThreshold: Double?
    enum CodingKeys: String, CodingKey {
        case id, name, barcode, unit, notes
        case categoryId = "category_id"
        case salePrice = "sale_price"
        case defaultPurchasePrice = "default_purchase_price"
        case itemType = "item_type"
        case lowStockThreshold = "low_stock_threshold"
    }
}

struct InventoryLocation: Decodable, Identifiable {
    let id: String
    let name: String
    let companyId: String?
    enum CodingKeys: String, CodingKey {
        case id, name
        case companyId = "company_id"
    }
}

struct InventoryStockRow: Decodable, Identifiable {
    let id: String
    let locationId: String
    let itemId: String
    let quantity: Double
    enum CodingKeys: String, CodingKey {
        case id
        case locationId = "location_id"
        case itemId = "item_id"
        case quantity
    }
}

// MARK: - Inventory Payloads

struct InventoryItemCreatePayload: Encodable {
    let name: String
    let barcode: String?
    let categoryId: String?
    let salePrice: Double?
    let defaultPurchasePrice: Double?
    let unit: String?
    let notes: String?
    let itemType: String?
    let lowStockThreshold: Double?
    enum CodingKeys: String, CodingKey {
        case name, barcode, unit, notes
        case categoryId = "category_id"
        case salePrice = "sale_price"
        case defaultPurchasePrice = "default_purchase_price"
        case itemType = "item_type"
        case lowStockThreshold = "low_stock_threshold"
    }
}

struct InventoryReceiptLinePayload: Encodable {
    let itemId: String
    let quantity: Double
    let unitCost: Double
    let comment: String?
    enum CodingKeys: String, CodingKey {
        case quantity, comment
        case itemId = "item_id"
        case unitCost = "unit_cost"
    }
}

struct InventoryReceiptPayload: Encodable {
    let locationId: String
    let supplierId: String?
    let receivedAt: String
    let invoiceNumber: String?
    let comment: String?
    let items: [InventoryReceiptLinePayload]
    enum CodingKeys: String, CodingKey {
        case comment, items
        case locationId = "location_id"
        case supplierId = "supplier_id"
        case receivedAt = "received_at"
        case invoiceNumber = "invoice_number"
    }
}

struct InventoryRequestLinePayload: Encodable {
    let itemId: String
    let requestedQty: Double
    let comment: String?
    enum CodingKeys: String, CodingKey {
        case comment
        case itemId = "item_id"
        case requestedQty = "requested_qty"
    }
}

struct InventoryWriteoffLinePayload: Encodable {
    let itemId: String
    let quantity: Double
    let comment: String?
    enum CodingKeys: String, CodingKey {
        case quantity, comment
        case itemId = "item_id"
    }
}

// MARK: - Monthly Report Models

struct MonthlyReportData: Decodable {
    let daily: [DailySaleRow]
    let totals: MonthlySaleTotals
    let year: Int
    let month: Int
}

struct DailySaleRow: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let count: Int
    let total: Int
    let cash: Int
    let kaspi: Int
    let card: Int
    let online: Int
    let discount: Int
}

struct MonthlySaleTotals: Decodable {
    let count: Int
    let total: Int
    let cash: Int
    let kaspi: Int
    let card: Int
    let online: Int
    let discount: Int
    let avgCheck: Int
    enum CodingKeys: String, CodingKey {
        case count, total, cash, kaspi, card, online, discount
        case avgCheck = "avg_check"
    }
}

struct PointTransaction: Decodable, Identifiable {
    let id: String
    let saleDate: String
    let totalAmount: Double
    let cashAmount: Double?
    let kaspiAmount: Double?
    let cardAmount: Double?
    let onlineAmount: Double?
    let discountAmount: Double?
    let loyaltyDiscountAmount: Double?
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

// MARK: - KPI Dashboard Models

struct KpiDashboardData: Decodable {
    let collectivePlans: [KpiPlan]
    let weekRows: [KpiIncomeRow]
    let monthRows: [KpiIncomeRow]
    let weekdayShare: [String: Double]
    let operatorNames: [String: String]
    enum CodingKeys: String, CodingKey {
        case weekRows = "weekRows"
        case monthRows = "monthRows"
        case weekdayShare = "weekdayShare"
        case operatorNames = "operatorNames"
        case collectivePlans = "collectivePlans"
    }
}

struct KpiPlan: Decodable, Identifiable {
    var id: String { planKey }
    let planKey: String
    let monthStart: String
    let entityType: String
    let companyCode: String?
    let operatorId: String?
    let roleCode: String?
    let turnoverTargetMonth: Double
    let turnoverTargetWeek: Double
    let shiftsTargetMonth: Double
    let shiftsTargetWeek: Double
    let isLocked: Bool
    enum CodingKeys: String, CodingKey {
        case planKey = "plan_key"
        case monthStart = "month_start"
        case entityType = "entity_type"
        case companyCode = "company_code"
        case operatorId = "operator_id"
        case roleCode = "role_code"
        case turnoverTargetMonth = "turnover_target_month"
        case turnoverTargetWeek = "turnover_target_week"
        case shiftsTargetMonth = "shifts_target_month"
        case shiftsTargetWeek = "shifts_target_week"
        case isLocked = "is_locked"
    }
}

struct KpiIncomeRow: Decodable {
    let date: String
    let cashAmount: Double?
    let kaspiAmount: Double?
    let cardAmount: Double?
    let operatorId: String?
    enum CodingKeys: String, CodingKey {
        case date
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case cardAmount = "card_amount"
        case operatorId = "operator_id"
    }
    var total: Double { (cashAmount ?? 0) + (kaspiAmount ?? 0) + (cardAmount ?? 0) }
}

// MARK: - Operator Career Models

struct OperatorCareerLink: Decodable, Identifiable {
    let id: String
    let assignedRole: String
    let assignedAt: String
    let updatedAt: String
    let staff: CareerStaffRow?
    enum CodingKeys: String, CodingKey {
        case id
        case assignedRole = "assigned_role"
        case assignedAt = "assigned_at"
        case updatedAt = "updated_at"
        case staff
    }
}

struct CareerStaffRow: Decodable {
    let id: String
    let fullName: String?
    let shortName: String?
    let role: String?
    let monthlySalary: Double?
    let email: String?
    let phone: String?
    let isActive: Bool?
    enum CodingKeys: String, CodingKey {
        case id, role, email, phone, fullName, shortName, monthlySalary, isActive
    }
}

// MARK: - Categories Models

struct AdminCategory: Decodable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let color: String?
    let parentId: String?
    /// `GET /api/admin/expense-categories` (f16finance)
    let accountingGroup: String?
    let monthlyBudget: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, type, color, parentId
        case accountingGroup = "accounting_group"
        case monthlyBudget = "monthly_budget"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decodeIfPresent(String.self, forKey: .type)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        parentId = try c.decodeIfPresent(String.self, forKey: .parentId)
        accountingGroup = try c.decodeIfPresent(String.self, forKey: .accountingGroup)
        monthlyBudget = try Self.decodeOptionalDouble(c, key: .monthlyBudget)
    }

    private static func decodeOptionalDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? c.decodeIfPresent(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }
}

struct CategoryCreatePayload: Encodable {
    let name: String
    let accountingGroup: String
    let monthlyBudget: Double

    enum CodingKeys: String, CodingKey {
        case name
        case accountingGroup = "accounting_group"
        case monthlyBudget = "monthly_budget"
    }
}

// MARK: - F3.2 Orda Market

struct ClientCatalogItem: Decodable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let categoryName: String?
    let imageUrl: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, price, description
        case categoryName = "category_name"
        case imageUrl = "image_url"
    }
}

struct PreorderPayload: Encodable {
    let items: [PreorderLinePayload]
    let pointId: String?

    enum CodingKeys: String, CodingKey {
        case items
        case pointId = "point_id"
    }
}

struct PreorderLinePayload: Encodable {
    let itemId: String
    let quantity: Int

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

// MARK: - F3.3 Orda Pay

struct ClientBalance: Decodable {
    let balance: Double
    let currency: String?

    enum CodingKeys: String, CodingKey {
        case balance, currency
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        balance = try c.decode(Double.self, forKey: .balance)
        currency = try c.decodeIfPresent(String.self, forKey: .currency)
    }
}

struct ClientBalanceTransaction: Decodable, Identifiable {
    let id: String
    let amount: Double
    let type: String
    let description: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, amount, type, description
        case createdAt = "created_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        amount = try c.decode(Double.self, forKey: .amount)
        type = try c.decode(String.self, forKey: .type)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        createdAt = try c.decode(String.self, forKey: .createdAt)
    }
}

// MARK: - F3.4 Achievements + Referral

struct ClientAchievement: Decodable, Identifiable {
    let id: String
    let key: String
    let title: String
    let description: String?
    let emoji: String?
    let isUnlocked: Bool
    let unlockedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, key, title, description, emoji
        case isUnlocked = "is_unlocked"
        case unlockedAt = "unlocked_at"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        key = try c.decode(String.self, forKey: .key)
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        emoji = try c.decodeIfPresent(String.self, forKey: .emoji)
        isUnlocked = try c.decodeIfPresent(Bool.self, forKey: .isUnlocked) ?? false
        unlockedAt = try c.decodeIfPresent(String.self, forKey: .unlockedAt)
    }
}

struct ClientReferralInfo: Decodable {
    let code: String
    let invitedCount: Int
    let pointsEarned: Int

    enum CodingKeys: String, CodingKey {
        case code
        case invitedCount = "invited_count"
        case pointsEarned = "points_earned"
    }

    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code)
        invitedCount = try c.decodeIfPresent(Int.self, forKey: .invitedCount) ?? 0
        pointsEarned = try c.decodeIfPresent(Int.self, forKey: .pointsEarned) ?? 0
    }
}

// MARK: - Smart Alerts

struct SmartAlert: Decodable, Identifiable {
    let id: String
    let type: String
    let message: String
    let severity: String
    let createdAt: String
    let actionLabel: String?

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case message
        case severity
        case createdAt = "created_at"
        case actionLabel = "action_label"
    }

    var severityColor: String {
        switch severity {
        case "critical": return "error"
        case "warning": return "warning"
        default: return "info"
        }
    }
}

// MARK: - Shift Swap

struct ShiftSwapRequest: Decodable, Identifiable {
    let id: String
    let shiftDate: String
    let shiftType: String
    let reason: String?
    let status: String
    let requesterName: String?
    let acceptorName: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case shiftDate = "shift_date"
        case shiftType = "shift_type"
        case reason
        case status
        case requesterName = "requester_name"
        case acceptorName = "acceptor_name"
        case createdAt = "created_at"
    }
}

struct ShiftSwapCreatePayload: Encodable {
    let shiftDate: String
    let shiftType: String
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case shiftDate = "shift_date"
        case shiftType = "shift_type"
        case reason
    }
}

// MARK: - Station Booking

struct ClientStation: Decodable, Identifiable {
    let id: String
    let number: Int
    let status: String
    let sessionMinutesLeft: Int?
    let companyId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case number
        case status
        case sessionMinutesLeft = "session_minutes_left"
        case companyId = "company_id"
    }
}

struct StationBookingPayload: Encodable {
    let stationId: String
    let durationMinutes: Int
    let startTime: String
    let companyId: String?

    enum CodingKeys: String, CodingKey {
        case stationId = "station_id"
        case durationMinutes = "duration_minutes"
        case startTime = "start_time"
        case companyId
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(stationId, forKey: .stationId)
        try c.encode(durationMinutes, forKey: .durationMinutes)
        try c.encode(startTime, forKey: .startTime)
        try c.encodeIfPresent(companyId, forKey: .companyId)
    }
}

// MARK: - F4.3 Broadcast

struct BroadcastMessage: Decodable, Identifiable {
    let id: String
    let title: String
    let body: String
    let sentAt: String
    let sentByName: String?
    let recipientCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, body
        case sentAt = "sent_at"
        case sentByName = "sent_by_name"
        case recipientCount = "recipient_count"
    }
}

struct BroadcastCreatePayload: Encodable {
    let title: String
    let body: String
}

// MARK: - F4.6 Team Feed

struct FeedPost: Decodable, Identifiable {
    let id: String
    let content: String
    let authorName: String?
    let likesCount: Int
    let createdAt: String
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, content
        case authorName = "author_name"
        case likesCount = "likes_count"
        case createdAt = "created_at"
        case imageUrl = "image_url"
    }
}

struct FeedCreatePayload: Encodable {
    let content: String
}
