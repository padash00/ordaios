import Foundation

protocol AdminContractsServicing {
    func loadDashboard() async throws -> AdminDashboardPayload

    func loadIncomes() async throws -> [AdminIncome]
    func loadIncomesRange(from: String, to: String) async throws -> [AdminIncome]
    func createIncome(_ payload: IncomeCreatePayload) async throws
    func updateIncome(id: String, payload: IncomeCreatePayload) async throws
    func deleteIncome(id: String) async throws

    func loadExpenses() async throws -> [AdminExpense]
    func loadExpensesRange(from: String, to: String) async throws -> [AdminExpense]
    func createExpense(_ payload: ExpenseCreatePayload) async throws
    func updateExpense(id: String, payload: ExpenseCreatePayload) async throws
    func deleteExpense(id: String) async throws

    func loadShifts(weekStart: String) async throws -> AdminShiftWorkflowResponse
    func saveShift(_ payload: ShiftSavePayload) async throws
    func bulkAssignWeek(_ payload: ShiftBulkAssignWeekPayload) async throws
    func publishWeek(_ payload: ShiftPublishWeekPayload) async throws
    func resolveShiftIssue(_ payload: ShiftResolveIssuePayload) async throws

    func loadTasks() async throws -> [AdminTask]
    func createTask(_ payload: TaskCreatePayload) async throws
    func deleteTask(taskId: String) async throws
    func changeTaskStatus(taskId: String, status: String) async throws
    func respondTask(taskId: String, response: String, note: String?) async throws
    func addTaskComment(taskId: String, content: String) async throws

    func loadOperators() async throws -> [AdminOperator]
    func createOperator(_ payload: OperatorCreatePayload) async throws
    func updateOperator(operatorId: String, payload: OperatorCreatePayload) async throws
    func deleteOperator(operatorId: String) async throws
    func toggleOperatorActive(operatorId: String, isActive: Bool) async throws
    func loadOperatorProfile(operatorId: String) async throws -> AdminOperatorProfilePayload
    func updateOperatorProfile(_ payload: AdminOperatorProfilePatchRequest) async throws

    func loadCustomers() async throws -> [AdminCustomer]
    func createCustomer(_ payload: CustomerCreatePayload) async throws
    func loadCustomerHistory(customerId: String) async throws -> [AdminCustomerSale]

    func loadSalaryWeek(weekStart: String) async throws -> SalaryWeekBoard
    func createSalaryAdjustment(operatorId: String, date: String, amount: Double, kind: String, comment: String?, companyId: String?) async throws
    func createSalaryWeeklyPayment(operatorId: String, weekStart: String, paymentDate: String, cashAmount: Double?, kaspiAmount: Double?, comment: String?) async throws
    func voidSalaryPayment(paymentId: String, weekStart: String, operatorId: String) async throws
    func loadSalaryRules() async throws -> SalaryRulesBoard

    func loadProfitability(from: String, to: String, includeKaspiDaily: Bool) async throws -> AdminProfitabilityData

    func loadCompanies() async throws -> [AdminCompany]
    func loadCategories() async throws -> [AdminCategory]
    func createCategory(_ payload: CategoryCreatePayload) async throws
    func deleteCategory(categoryId: String) async throws

    // Point Devices
    func loadPointDevices() async throws -> PointDevicesResponse
    func createPointProject(name: String, companyIds: [String], flags: PointFeatureFlagsPayload) async throws
    func updatePointProject(projectId: String, name: String, companyIds: [String], flags: PointFeatureFlagsPayload) async throws
    func togglePointProject(projectId: String, isActive: Bool) async throws
    func rotatePointToken(projectId: String) async throws
    func deletePointProject(projectId: String) async throws

    // Inventory
    func loadInventoryOverview() async throws -> InventoryOverview
    func createInventoryItem(_ payload: InventoryItemCreatePayload) async throws
    func createInventoryReceipt(_ payload: InventoryReceiptPayload) async throws
    func createInventoryWriteoff(locationId: String, reason: String, writtenAt: String, comment: String?, items: [InventoryWriteoffLinePayload]) async throws

    // Monthly Reports
    func loadMonthlyReport(year: Int, month: Int, companyId: String?) async throws -> MonthlyReportData
    func loadDayTransactions(day: String, companyId: String?) async throws -> [PointTransaction]

    // KPI Dashboard
    func loadKpiDashboard(monthStart: String, weekStart: String, weekEnd: String) async throws -> KpiDashboardData

    // Operator Career
    func loadOperatorCareer(operatorId: String) async throws -> OperatorCareerLink?
    func promoteOperator(operatorId: String, role: String, monthlySalary: Double?) async throws
}

final class AdminContractsService: AdminContractsServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func loadDashboard() async throws -> AdminDashboardPayload {
        let endpoint = APIEndpoint(path: "/api/admin/dashboard", method: .GET)
        let response: AdminDashboardEnvelope = try await apiClient.request(endpoint)
        return response.data
    }

    func loadIncomes() async throws -> [AdminIncome] {
        let response: DataListResponse<AdminIncome> = try await apiClient.request(ContractEndpoint.api_admin_incomes.get)
        return response.data
    }

    func loadIncomesRange(from: String, to: String) async throws -> [AdminIncome] {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_incomes.rawValue,
            method: .GET,
            queryItems: [URLQueryItem(name: "from", value: from), URLQueryItem(name: "to", value: to)]
        )
        let response: DataListResponse<AdminIncome> = try await apiClient.request(endpoint)
        return response.data
    }

    func createIncome(_ payload: IncomeCreatePayload) async throws {
        let request = AdminIncomeActionRequest(action: "createIncome", payload: payload, incomeId: nil, onlineAmount: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_incomes.post, body: request)
    }

    func updateIncome(id: String, payload: IncomeCreatePayload) async throws {
        let request = AdminIncomeActionRequest(action: "updateIncome", payload: payload, incomeId: id, onlineAmount: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_incomes.post, body: request)
    }

    func deleteIncome(id: String) async throws {
        let request = AdminIncomeActionRequest(action: "deleteIncome", payload: nil, incomeId: id, onlineAmount: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_incomes.post, body: request)
    }

    func loadExpenses() async throws -> [AdminExpense] {
        let response: DataListResponse<AdminExpense> = try await apiClient.request(ContractEndpoint.api_admin_expenses.get)
        return response.data
    }

    func loadExpensesRange(from: String, to: String) async throws -> [AdminExpense] {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_expenses.rawValue,
            method: .GET,
            queryItems: [
                URLQueryItem(name: "from", value: from),
                URLQueryItem(name: "to", value: to),
                URLQueryItem(name: "page_size", value: "2000"),
                URLQueryItem(name: "page", value: "0")
            ]
        )
        let response: DataListResponse<AdminExpense> = try await apiClient.request(endpoint)
        return response.data
    }

    func createExpense(_ payload: ExpenseCreatePayload) async throws {
        let request = AdminExpenseActionRequest(action: "createExpense", payload: payload, expenseId: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_expenses.post, body: request)
    }

    func updateExpense(id: String, payload: ExpenseCreatePayload) async throws {
        let request = AdminExpenseActionRequest(action: "updateExpense", payload: payload, expenseId: id)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_expenses.post, body: request)
    }

    func deleteExpense(id: String) async throws {
        let request = AdminExpenseActionRequest(action: "deleteExpense", payload: nil, expenseId: id)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_expenses.post, body: request)
    }

    func loadShifts(weekStart: String) async throws -> AdminShiftWorkflowResponse {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_shifts.rawValue,
            method: .GET,
            queryItems: [
                URLQueryItem(name: "weekStart", value: weekStart),
                URLQueryItem(name: "includeSchedule", value: "1")
            ]
        )
        let response: AdminShiftWorkflowResponse = try await apiClient.request(endpoint)
        return response
    }

    func saveShift(_ payload: ShiftSavePayload) async throws {
        let request = AdminShiftActionRequest(action: "saveShift", payload: payload)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_shifts.post, body: request)
    }

    func bulkAssignWeek(_ payload: ShiftBulkAssignWeekPayload) async throws {
        let request = AdminShiftBulkAssignWeekRequest(action: "bulkAssignWeek", payload: payload)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_shifts.post, body: request)
    }

    func publishWeek(_ payload: ShiftPublishWeekPayload) async throws {
        let request = AdminShiftPublishWeekRequest(action: "publishWeek", payload: payload)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_shifts.post, body: request)
    }

    func resolveShiftIssue(_ payload: ShiftResolveIssuePayload) async throws {
        let request = AdminShiftResolveIssueRequest(action: "resolveIssue", payload: payload)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_shifts.post, body: request)
    }

    func loadTasks() async throws -> [AdminTask] {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_tasks.rawValue,
            method: .GET,
            queryItems: [URLQueryItem(name: "includeLookups", value: "1")]
        )
        let response: DataListResponse<AdminTask> = try await apiClient.request(endpoint)
        return response.data
    }

    func deleteTask(taskId: String) async throws {
        let request = AdminTaskActionRequest(action: "deleteTask", payload: nil, taskId: taskId, status: nil, response: nil, note: nil, content: nil, message: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_tasks.post, body: request)
    }

    func createTask(_ payload: TaskCreatePayload) async throws {
        let request = AdminTaskActionRequest(
            action: "createTask",
            payload: payload,
            taskId: nil,
            status: nil,
            response: nil,
            note: nil,
            content: nil,
            message: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_tasks.post, body: request)
    }

    func changeTaskStatus(taskId: String, status: String) async throws {
        let request = AdminTaskActionRequest(
            action: "changeStatus",
            payload: nil,
            taskId: taskId,
            status: status,
            response: nil,
            note: nil,
            content: nil,
            message: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_tasks.post, body: request)
    }

    func respondTask(taskId: String, response: String, note: String?) async throws {
        let request = AdminTaskActionRequest(
            action: "respondTask",
            payload: nil,
            taskId: taskId,
            status: nil,
            response: response,
            note: note,
            content: nil,
            message: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_tasks.post, body: request)
    }

    func addTaskComment(taskId: String, content: String) async throws {
        let request = AdminTaskActionRequest(
            action: "addComment",
            payload: nil,
            taskId: taskId,
            status: nil,
            response: nil,
            note: nil,
            content: content,
            message: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_tasks.post, body: request)
    }

    func loadOperators() async throws -> [AdminOperator] {
        // Strict `[AdminOperator]` decode (not `DataListResponse` + failable elements) so a bad row surfaces as an error instead of an empty list.
        struct Envelope: Decodable {
            let data: [AdminOperator]
        }
        let env: Envelope = try await apiClient.request(ContractEndpoint.api_admin_operators.get)
        return env.data
    }

    func createOperator(_ payload: OperatorCreatePayload) async throws {
        let request = AdminOperatorActionRequest(
            action: "createOperator",
            payload: payload,
            operatorId: nil,
            isActive: nil,
            operatorIds: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_operators.post, body: request)
    }

    func updateOperator(operatorId: String, payload: OperatorCreatePayload) async throws {
        let request = AdminOperatorActionRequest(
            action: "updateOperator",
            payload: payload,
            operatorId: operatorId,
            isActive: nil,
            operatorIds: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_operators.post, body: request)
    }

    func deleteOperator(operatorId: String) async throws {
        let request = AdminOperatorActionRequest(action: "deleteOperator", payload: nil, operatorId: operatorId, isActive: nil, operatorIds: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_operators.post, body: request)
    }

    func toggleOperatorActive(operatorId: String, isActive: Bool) async throws {
        let request = AdminOperatorActionRequest(
            action: "toggleOperatorActive",
            payload: nil,
            operatorId: operatorId,
            isActive: isActive,
            operatorIds: nil
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_operators.post, body: request)
    }

    func loadOperatorProfile(operatorId: String) async throws -> AdminOperatorProfilePayload {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_operators_profile.rawValue,
            method: .GET,
            queryItems: [URLQueryItem(name: "operator_id", value: operatorId)]
        )
        let response: AdminOperatorProfileEnvelope = try await apiClient.request(endpoint)
        return response.data
    }

    func updateOperatorProfile(_ payload: AdminOperatorProfilePatchRequest) async throws {
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_operators_profile.patch, body: payload)
    }

    func loadCustomers() async throws -> [AdminCustomer] {
        do {
            let response: AdminCustomerListEnvelope = try await apiClient.request(ContractEndpoint.api_admin_customers.get)
            #if DEBUG
            print("[AdminCustomers] decoded items:", response.data.count)
            #endif
            return response.data
        } catch {
            #if DEBUG
            print("[AdminCustomers] decode/load error:", error.localizedDescription)
            #endif
            throw error
        }
    }

    func createCustomer(_ payload: CustomerCreatePayload) async throws {
        let request = AdminCustomerActionRequest(action: "createCustomer", payload: payload, customerId: nil, delta: nil)
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_customers.post, body: request)
    }

    func loadCustomerHistory(customerId: String) async throws -> [AdminCustomerSale] {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_customers_history.rawValue,
            method: .GET,
            queryItems: [URLQueryItem(name: "customer_id", value: customerId)]
        )
        let response: AdminCustomerHistoryResponse = try await apiClient.request(endpoint)
        return response.sales
    }

    func loadSalaryWeek(weekStart: String) async throws -> SalaryWeekBoard {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_salary.rawValue,
            method: .GET,
            queryItems: [
                URLQueryItem(name: "view", value: "weekly"),
                URLQueryItem(name: "weekStart", value: weekStart),
            ]
        )
        struct Envelope: Decodable {
            let data: SalaryWeekBoard
        }
        let env: Envelope = try await apiClient.request(endpoint)
        return env.data
    }

    func createSalaryAdjustment(operatorId: String, date: String, amount: Double, kind: String, comment: String?, companyId: String?) async throws {
        let body = SalaryActionBody(
            action: "createAdjustment",
            payload: SalaryAdjustmentData(operatorId: operatorId, date: date, amount: amount, kind: kind, comment: comment, companyId: companyId)
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_salary.post, body: body)
    }

    func createSalaryWeeklyPayment(operatorId: String, weekStart: String, paymentDate: String, cashAmount: Double?, kaspiAmount: Double?, comment: String?) async throws {
        let body = SalaryActionBody(
            action: "createWeeklyPayment",
            payload: SalaryWeeklyPaymentData(
                operatorId: operatorId,
                weekStart: weekStart,
                paymentDate: paymentDate,
                cashAmount: cashAmount,
                kaspiAmount: kaspiAmount,
                comment: comment
            )
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_salary.post, body: body)
    }

    func voidSalaryPayment(paymentId: String, weekStart: String, operatorId: String) async throws {
        let body = SalaryActionBody(
            action: "voidPayment",
            payload: SalaryVoidPaymentData(paymentId: paymentId, weekStart: weekStart, operatorId: operatorId)
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_salary.post, body: body)
    }

    func loadSalaryRules() async throws -> SalaryRulesBoard {
        struct Envelope: Decodable {
            let data: SalaryRulesBoard
        }
        let env: Envelope = try await apiClient.request(ContractEndpoint.api_admin_salary_rules.get)
        return env.data
    }

    func loadProfitability(from: String, to: String, includeKaspiDaily: Bool) async throws -> AdminProfitabilityData {
        var queryItems = [
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to)
        ]
        if includeKaspiDaily {
            queryItems.append(URLQueryItem(name: "include_kaspi_daily", value: "1"))
            queryItems.append(URLQueryItem(name: "includeKaspiDaily", value: "1"))
        }
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_profitability.rawValue,
            method: .GET,
            queryItems: queryItems
        )
        let payload: ProfitabilityListPayload = try await apiClient.request(endpoint)
        return Self.aggregateProfitability(from: payload.items)
    }

    func loadCompanies() async throws -> [AdminCompany] {
        let response: DataListResponse<AdminCompany> = try await apiClient.request(ContractEndpoint.api_admin_companies.get)
        return response.data
    }

    func loadCategories() async throws -> [AdminCategory] {
        let response: DataListResponse<AdminCategory> = try await apiClient.request(ContractEndpoint.api_admin_categories.get)
        return response.data
    }

    func createCategory(_ payload: CategoryCreatePayload) async throws {
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_categories.post, body: payload)
    }

    func deleteCategory(categoryId: String) async throws {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_categories.rawValue,
            method: .DELETE,
            queryItems: [URLQueryItem(name: "id", value: categoryId)]
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint)
    }

    // MARK: - Point Devices

    func loadPointDevices() async throws -> PointDevicesResponse {
        let response: PointDevicesResponse = try await apiClient.request(ContractEndpoint.api_admin_point_devices.get)
        return response
    }

    func createPointProject(name: String, companyIds: [String], flags: PointFeatureFlagsPayload) async throws {
        let body = PointDeviceActionBody(
            action: "createProject",
            payload: PointProjectCreatePayload(
                name: name,
                companyAssignments: companyIds.map { PointCompanyAssignmentPayload(companyId: $0) },
                featureFlags: flags
            )
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_point_devices.post, body: body)
    }

    func updatePointProject(projectId: String, name: String, companyIds: [String], flags: PointFeatureFlagsPayload) async throws {
        let body = PointDeviceActionBody(
            action: "updateProject",
            payload: PointProjectUpdatePayload(
                projectId: projectId,
                name: name,
                companyAssignments: companyIds.map { PointCompanyAssignmentPayload(companyId: $0) },
                featureFlags: flags
            )
        )
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_point_devices.post, body: body)
    }

    func togglePointProject(projectId: String, isActive: Bool) async throws {
        let body = PointDeviceActionBody(action: "toggleProjectActive", payload: PointToggleActivePayload(projectId: projectId, isActive: isActive))
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_point_devices.post, body: body)
    }

    func rotatePointToken(projectId: String) async throws {
        let body = PointDeviceActionBody(action: "rotateProjectToken", payload: PointRotateTokenPayload(projectId: projectId))
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_point_devices.post, body: body)
    }

    func deletePointProject(projectId: String) async throws {
        let body = PointDeviceActionBody(action: "deleteProject", payload: PointDeleteProjectPayload(projectId: projectId))
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_point_devices.post, body: body)
    }

    // MARK: - Inventory

    func loadInventoryOverview() async throws -> InventoryOverview {
        let response: InventoryOverview = try await apiClient.request(ContractEndpoint.api_admin_inventory.get)
        return response
    }

    func createInventoryItem(_ payload: InventoryItemCreatePayload) async throws {
        struct Body: Encodable { let action: String; let payload: InventoryItemCreatePayload }
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_inventory.post, body: Body(action: "createItem", payload: payload))
    }

    func createInventoryReceipt(_ payload: InventoryReceiptPayload) async throws {
        struct Body: Encodable { let action: String; let payload: InventoryReceiptPayload }
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_inventory.post, body: Body(action: "createReceipt", payload: payload))
    }

    func createInventoryWriteoff(locationId: String, reason: String, writtenAt: String, comment: String?, items: [InventoryWriteoffLinePayload]) async throws {
        struct WriteoffPayload: Encodable {
            let locationId: String; let reason: String; let writtenAt: String; let comment: String?; let items: [InventoryWriteoffLinePayload]
            enum CodingKeys: String, CodingKey { case locationId = "location_id"; case reason; case writtenAt = "written_at"; case comment; case items }
        }
        struct Body: Encodable { let action: String; let payload: WriteoffPayload }
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_inventory.post, body: Body(action: "createWriteoff", payload: WriteoffPayload(locationId: locationId, reason: reason, writtenAt: writtenAt, comment: comment, items: items)))
    }

    // MARK: - Monthly Reports

    func loadMonthlyReport(year: Int, month: Int, companyId: String?) async throws -> MonthlyReportData {
        var queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month))
        ]
        if let cid = companyId { queryItems.append(URLQueryItem(name: "company_id", value: cid)) }
        let endpoint = APIEndpoint(path: ContractEndpoint.api_admin_reports_monthly.rawValue, method: .GET, queryItems: queryItems)
        struct Envelope: Decodable { let data: MonthlyReportData }
        let env: Envelope = try await apiClient.request(endpoint)
        return env.data
    }

    func loadDayTransactions(day: String, companyId: String?) async throws -> [PointTransaction] {
        var queryItems = [URLQueryItem(name: "day", value: day)]
        if let cid = companyId { queryItems.append(URLQueryItem(name: "company_id", value: cid)) }
        let endpoint = APIEndpoint(path: ContractEndpoint.api_admin_incomes.rawValue, method: .GET, queryItems: queryItems)
        let response: DataListResponse<PointTransaction> = try await apiClient.request(endpoint)
        return response.data
    }

    // MARK: - KPI Dashboard

    func loadKpiDashboard(monthStart: String, weekStart: String, weekEnd: String) async throws -> KpiDashboardData {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_kpi_dashboard.rawValue,
            method: .GET,
            queryItems: [
                URLQueryItem(name: "monthStart", value: monthStart),
                URLQueryItem(name: "weekStart", value: weekStart),
                URLQueryItem(name: "weekEnd", value: weekEnd)
            ]
        )
        struct Envelope: Decodable { let data: KpiDashboardData }
        let env: Envelope = try await apiClient.request(endpoint)
        return env.data
    }

    // MARK: - Operator Career

    func loadOperatorCareer(operatorId: String) async throws -> OperatorCareerLink? {
        let endpoint = APIEndpoint(
            path: ContractEndpoint.api_admin_operator_career.rawValue,
            method: .GET,
            queryItems: [URLQueryItem(name: "operator_id", value: operatorId)]
        )
        struct Envelope: Decodable { let data: OperatorCareerLink? }
        let env: Envelope = try await apiClient.request(endpoint)
        return env.data
    }

    func promoteOperator(operatorId: String, role: String, monthlySalary: Double?) async throws {
        struct PromotePayload: Encodable {
            let operatorId: String; let role: String; let monthlySalary: Double?
            enum CodingKeys: String, CodingKey { case operatorId = "operator_id"; case role; case monthlySalary = "monthly_salary" }
        }
        struct Body: Encodable { let action: String; let payload: PromotePayload }
        let _: APIStatusResponse = try await apiClient.request(ContractEndpoint.api_admin_operator_career.post, body: Body(action: "promoteOperator", payload: PromotePayload(operatorId: operatorId, role: role, monthlySalary: monthlySalary)))
    }

    /// Builds P&L from `monthly_profitability_inputs` rows returned by `GET /api/admin/profitability` (same manual fields as the web form; journal COGS / income are not included).
    private static func aggregateProfitability(from rows: [ProfitabilityMonthInputRow]) -> AdminProfitabilityData {
        guard !rows.isEmpty else {
            return AdminProfitabilityData(
                revenue: 0,
                costOfGoods: 0,
                grossProfit: 0,
                grossMargin: 0,
                operatingExpenses: 0,
                ebitda: 0,
                netProfit: 0,
                netMargin: 0,
                period: nil,
                breakdown: nil
            )
        }

        var revenue = 0.0
        var posCommission = 0.0
        var payroll = 0.0
        var payrollTaxes = 0.0
        var incomeTax = 0.0
        var otherOperating = 0.0
        var depreciation = 0.0
        var amortization = 0.0

        for row in rows {
            revenue += row.cashRevenueOverride + row.posRevenueOverride
            posCommission += row.posCommissionTotal()
            payroll += row.payrollAmount
            payrollTaxes += row.payrollTaxesAmount
            incomeTax += row.incomeTaxAmount
            otherOperating += row.otherOperatingAmount
            depreciation += row.depreciationAmount
            amortization += row.amortizationAmount
        }

        let cogs = 0.0
        let grossProfit = revenue - cogs
        let journalOperating = 0.0
        let ebitda = grossProfit - journalOperating - posCommission - payroll - payrollTaxes - otherOperating
        let operatingProfit = ebitda - depreciation - amortization
        let netProfit = operatingProfit - incomeTax
        let operatingExpenseDisplay = payroll + payrollTaxes + otherOperating

        let grossMargin = revenue > 0.009 ? (grossProfit / revenue) * 100 : 0.0
        let netMargin = revenue > 0.009 ? (netProfit / revenue) * 100 : 0.0

        return AdminProfitabilityData(
            revenue: revenue,
            costOfGoods: cogs,
            grossProfit: grossProfit,
            grossMargin: grossMargin,
            operatingExpenses: operatingExpenseDisplay,
            ebitda: ebitda,
            netProfit: netProfit,
            netMargin: netMargin,
            period: nil,
            breakdown: nil
        )
    }
}

// MARK: - Profitability API payload (`{ items: [...] }`)

private struct ProfitabilityListPayload: Decodable {
    let items: [ProfitabilityMonthInputRow]
}

private struct ProfitabilityMonthInputRow: Decodable {
    let cashRevenueOverride: Double
    let posRevenueOverride: Double
    let kaspiQrTurnover: Double
    let kaspiQrRate: Double
    let kaspiGoldTurnover: Double
    let kaspiGoldRate: Double
    let qrGoldTurnover: Double
    let qrGoldRate: Double
    let otherCardsTurnover: Double
    let otherCardsRate: Double
    let kaspiRedTurnover: Double
    let kaspiRedRate: Double
    let kaspiKreditTurnover: Double
    let kaspiKreditRate: Double
    let payrollAmount: Double
    let payrollTaxesAmount: Double
    let incomeTaxAmount: Double
    let depreciationAmount: Double
    let amortizationAmount: Double
    let otherOperatingAmount: Double

    private enum CodingKeys: String, CodingKey {
        case cashRevenueOverride = "cash_revenue_override"
        case posRevenueOverride = "pos_revenue_override"
        case kaspiQrTurnover = "kaspi_qr_turnover"
        case kaspiQrRate = "kaspi_qr_rate"
        case kaspiGoldTurnover = "kaspi_gold_turnover"
        case kaspiGoldRate = "kaspi_gold_rate"
        case qrGoldTurnover = "qr_gold_turnover"
        case qrGoldRate = "qr_gold_rate"
        case otherCardsTurnover = "other_cards_turnover"
        case otherCardsRate = "other_cards_rate"
        case kaspiRedTurnover = "kaspi_red_turnover"
        case kaspiRedRate = "kaspi_red_rate"
        case kaspiKreditTurnover = "kaspi_kredit_turnover"
        case kaspiKreditRate = "kaspi_kredit_rate"
        case payrollAmount = "payroll_amount"
        case payrollTaxesAmount = "payroll_taxes_amount"
        case incomeTaxAmount = "income_tax_amount"
        case depreciationAmount = "depreciation_amount"
        case amortizationAmount = "amortization_amount"
        case otherOperatingAmount = "other_operating_amount"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        cashRevenueOverride = Self.decodeNumber(c, key: .cashRevenueOverride)
        posRevenueOverride = Self.decodeNumber(c, key: .posRevenueOverride)
        kaspiQrTurnover = Self.decodeNumber(c, key: .kaspiQrTurnover)
        kaspiQrRate = Self.decodeNumber(c, key: .kaspiQrRate)
        kaspiGoldTurnover = Self.decodeNumber(c, key: .kaspiGoldTurnover)
        kaspiGoldRate = Self.decodeNumber(c, key: .kaspiGoldRate)
        qrGoldTurnover = Self.decodeNumber(c, key: .qrGoldTurnover)
        qrGoldRate = Self.decodeNumber(c, key: .qrGoldRate)
        otherCardsTurnover = Self.decodeNumber(c, key: .otherCardsTurnover)
        otherCardsRate = Self.decodeNumber(c, key: .otherCardsRate)
        kaspiRedTurnover = Self.decodeNumber(c, key: .kaspiRedTurnover)
        kaspiRedRate = Self.decodeNumber(c, key: .kaspiRedRate)
        kaspiKreditTurnover = Self.decodeNumber(c, key: .kaspiKreditTurnover)
        kaspiKreditRate = Self.decodeNumber(c, key: .kaspiKreditRate)
        payrollAmount = Self.decodeNumber(c, key: .payrollAmount)
        payrollTaxesAmount = Self.decodeNumber(c, key: .payrollTaxesAmount)
        incomeTaxAmount = Self.decodeNumber(c, key: .incomeTaxAmount)
        depreciationAmount = Self.decodeNumber(c, key: .depreciationAmount)
        amortizationAmount = Self.decodeNumber(c, key: .amortizationAmount)
        otherOperatingAmount = Self.decodeNumber(c, key: .otherOperatingAmount)
    }

    private static func decodeNumber(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double {
        if let v = try? c.decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? c.decodeIfPresent(String.self, forKey: key), let v = Double(s) { return v }
        return 0
    }

    func posCommissionTotal() -> Double {
        let hasSplitQrGold = kaspiQrTurnover > 0 || kaspiGoldTurnover > 0
        let legacyQrGoldCommission = hasSplitQrGold ? 0 : (qrGoldTurnover * qrGoldRate / 100)
        let kaspiQrCommission = kaspiQrTurnover * kaspiQrRate / 100
        let kaspiGoldCommission = kaspiGoldTurnover * kaspiGoldRate / 100
        let otherCardsCommission = otherCardsTurnover * otherCardsRate / 100
        let kaspiRedCommission = kaspiRedTurnover * kaspiRedRate / 100
        let kaspiKreditCommission = kaspiKreditTurnover * kaspiKreditRate / 100
        return kaspiQrCommission + kaspiGoldCommission + otherCardsCommission + kaspiRedCommission + kaspiKreditCommission + legacyQrGoldCommission
    }
}

private struct AdminCustomerListEnvelope: Decodable {
    let data: [AdminCustomer]

    private enum CodingKeys: String, CodingKey {
        case data
        case ok
    }

    init(from decoder: Decoder) throws {
        if let rawList = try? [AdminCustomer](from: decoder) {
            data = rawList
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        data = try container.decodeIfPresent([AdminCustomer].self, forKey: .data) ?? []
    }
}

struct AdminDashboardEnvelope: Decodable {
    let data: AdminDashboardPayload

    private enum CodingKeys: String, CodingKey {
        case data
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self),
           container.contains(.data) {
            data = (try? container.decode(AdminDashboardPayload.self, forKey: .data)) ?? .empty
            return
        }
        data = (try? AdminDashboardPayload(from: decoder)) ?? .empty
    }
}

struct AdminDashboardPayload: Decodable {
    struct DayStat: Decodable {
        let total: Double
        let count: Int
        let cash: Double
        let kaspi: Double
        let card: Double
        let online: Double

        static let empty = DayStat(total: 0, count: 0, cash: 0, kaspi: 0, card: 0, online: 0)

        init(total: Double, count: Int, cash: Double, kaspi: Double, card: Double, online: Double) {
            self.total = total
            self.count = count
            self.cash = cash
            self.kaspi = kaspi
            self.card = card
            self.online = online
        }
    }

    let today: DayStat
    let yesterdayTotal: Double
    let changePercent: Double?
    let monthTotal: Double
    let weekByDay: [String: Double]

    static let empty = AdminDashboardPayload(
        today: .empty,
        yesterdayTotal: 0,
        changePercent: nil,
        monthTotal: 0,
        weekByDay: [:]
    )

    init(today: DayStat, yesterdayTotal: Double, changePercent: Double?, monthTotal: Double, weekByDay: [String: Double]) {
        self.today = today
        self.yesterdayTotal = yesterdayTotal
        self.changePercent = changePercent
        self.monthTotal = monthTotal
        self.weekByDay = weekByDay
    }

    private enum CodingKeys: String, CodingKey {
        case today
        case yesterday
        case changePercent = "change_percent"
        case monthTotal = "month_total"
        case weekByDay = "week_by_day"
    }

    private enum YesterdayCodingKeys: String, CodingKey {
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        today = (try? container.decode(DayStat.self, forKey: .today)) ?? .empty
        if let yesterdayContainer = try? container.nestedContainer(keyedBy: YesterdayCodingKeys.self, forKey: .yesterday) {
            yesterdayTotal = (try? yesterdayContainer.decode(Double.self, forKey: .total)) ?? 0
        } else {
            yesterdayTotal = 0
        }
        changePercent = try? container.decodeIfPresent(Double.self, forKey: .changePercent)
        monthTotal = (try? container.decode(Double.self, forKey: .monthTotal)) ?? 0
        weekByDay = (try? container.decode([String: Double].self, forKey: .weekByDay)) ?? [:]
    }
}
