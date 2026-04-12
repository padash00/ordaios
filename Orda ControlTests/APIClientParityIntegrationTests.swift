import XCTest
@testable import Orda_Control

final class APIClientParityIntegrationTests: XCTestCase {
    private var fixtureRoot: [String: Any] = [:]

    override func setUpWithError() throws {
        fixtureRoot = try Self.parseFixtureRoot()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testDecodeRegistrationOptionsFlatShape() async throws {
        let payload = try fixtureData(endpoint: "api/public/client/options", variant: "flat")
        let client = makeClient(statusCode: 200, data: payload)

        let response: ClientRegistrationOptionsResponse = try await client.request(
            APIEndpoint(path: "/api/public/client/options", method: .GET)
        )

        XCTAssertEqual(response.companies.count, 1)
        XCTAssertEqual(response.points.count, 1)
    }

    func testDecodeRegistrationOptionsDataEnvelopeShape() async throws {
        let payload = try fixtureData(endpoint: "api/public/client/options", variant: "data_envelope")
        let client = makeClient(statusCode: 200, data: payload)

        let response: ClientRegistrationOptionsResponse = try await client.request(
            APIEndpoint(path: "/api/public/client/options", method: .GET)
        )

        XCTAssertEqual(response.companies.first?.code, "f16")
        XCTAssertEqual(response.points.first?.id, "p1")
    }

    func testDecodeAdminCustomersRawListEnvelope() async throws {
        let payload = try fixtureData(endpoint: "api/admin/customers", variant: "raw_list")
        let client = makeClient(statusCode: 200, data: payload)

        let response: DataListResponse<AdminCustomer> = try await client.request(
            APIEndpoint(path: "/api/admin/customers", method: .GET)
        )

        XCTAssertEqual(response.data.count, 2)
    }

    func testDecodeAdminCustomersLossyListSkipsBrokenItems() async throws {
        let payload = try fixtureData(endpoint: "api/admin/customers", variant: "lossy_bad_item")
        let client = makeClient(statusCode: 200, data: payload)

        let response: DataListResponse<AdminCustomer> = try await client.request(
            APIEndpoint(path: "/api/admin/customers", method: .GET)
        )

        XCTAssertEqual(response.data.count, 1)
        XCTAssertEqual(response.data.first?.id, "1")
    }

    func testMap403ToForbiddenRussianMessage() async throws {
        let payload = try fixtureData(endpoint: "errors", variant: "forbidden")
        let client = makeClient(statusCode: 403, data: payload)

        do {
            let _: APIStatusResponse = try await client.request(APIEndpoint(path: "/api/admin/customers", method: .POST))
            XCTFail("Expected forbidden")
        } catch {
            guard let apiError = error as? APIError else {
                XCTFail("Expected APIError, got \(error)")
                return
            }
            XCTAssertEqual(apiError, .forbidden)
            XCTAssertEqual(apiError.errorDescription, "Нет доступа для этой роли.")
        }
    }

    func test401RetryOnceThenUnauthorizedHandler() async throws {
        let unauthorizedData = try fixtureData(endpoint: "errors", variant: "unauthorized")
        var callCount = 0
        var unauthorizedTriggered = false
        var refreshCount = 0

        let client = makeClientDynamic { request in
            callCount += 1
            return (401, unauthorizedData, request.url!)
        }
        client.setTokenProvider { "expired-token" }
        client.setTokenRefresher {
            refreshCount += 1
            return true
        }
        client.setUnauthorizedHandler {
            unauthorizedTriggered = true
        }

        do {
            let _: APIStatusResponse = try await client.request(APIEndpoint(path: "/api/auth/session-role", method: .GET))
            XCTFail("Expected unauthorized after retry")
        } catch {
            XCTAssertEqual(error as? APIError, .unauthorized)
        }

        XCTAssertEqual(callCount, 2, "Must retry exactly once")
        XCTAssertEqual(refreshCount, 1, "Must refresh exactly once")
        XCTAssertTrue(unauthorizedTriggered, "Unauthorized handler must be called after failed retry")
    }

    func testTimeoutMapsToRussianNetworkMessage() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.timedOut)
        }
        let client = APIClient(config: .integrationTest, session: session)

        do {
            let _: APIStatusResponse = try await client.request(APIEndpoint(path: "/api/admin/customers", method: .GET))
            XCTFail("Expected timeout")
        } catch {
            guard let apiError = error as? APIError else {
                XCTFail("Expected APIError")
                return
            }
            XCTAssertEqual(apiError, .timeout)
            XCTAssertEqual(apiError.errorDescription, "Ошибка сети. Повторите попытку.")
        }
    }

    func testDecodeInventoryRequestsDataEnvelope() async throws {
        let payload = try fixtureData(endpoint: "api/admin/inventory/requests", variant: "ok_data")
        let client = makeClient(statusCode: 200, data: payload)
        let service = P0ModulesService(apiClient: client)

        let requests = try await service.fetchInventoryRequests()

        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.id, "req1")
    }

    func testDecodeStoreOverviewDataEnvelope() async throws {
        let payload = try fixtureData(endpoint: "api/admin/store/overview", variant: "ok_data")
        let client = makeClient(statusCode: 200, data: payload)
        let service = P0ModulesService(apiClient: client)

        let data = try await service.fetchStoreOverview()

        XCTAssertEqual(data.totals?.sku, 12)
    }

    func testDecodePOSAndPointBootstrapEnvelopes() async throws {
        var callCount = 0
        let posPayload = try fixtureData(endpoint: "api/pos/bootstrap", variant: "ok_data")
        let pointPayload = try fixtureData(endpoint: "api/point/bootstrap", variant: "ok_data")
        let client = makeClientDynamic { request in
            callCount += 1
            if request.url?.path == "/api/pos/bootstrap" {
                return (200, posPayload, request.url!)
            }
            return (200, pointPayload, request.url!)
        }
        let service = P0ModulesService(apiClient: client)

        let pos = try await service.fetchPOSBootstrap()
        let point = try await service.fetchPointBootstrap()

        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(pos.items.count, 1)
        XCTAssertEqual(point.operators.count, 1)
    }

    func testPOSWriteFlowsSaleAndReturn() async throws {
        let salePayload = try fixtureData(endpoint: "api/pos/sale", variant: "success")
        let returnPayload = try fixtureData(endpoint: "api/pos/return", variant: "success")
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            switch path {
            case let p where p.hasSuffix("/api/pos/sale"):
                return (200, salePayload, request.url!)
            case let p where p.hasSuffix("/api/pos/return"):
                return (200, returnPayload, request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }
        let service = P0ModulesService(apiClient: client)

        do {
            try await service.createPOSSale(payload: POSSalePayload(
                companyId: "c1", locationId: "l1", items: [.init(itemId: "it1", quantity: 1)],
                cashAmount: 1200, kaspiAmount: 0, onlineAmount: 0, cardAmount: 0, note: nil
            ))
        } catch {
            XCTFail("sale failed: \(error)")
            return
        }
        do {
            try await service.createPOSReturn(payload: .init(saleId: "sale1", items: [.init(itemId: "it1", quantity: 1, unitPrice: 1200)], reason: "test"))
        } catch {
            XCTFail("return failed: \(error)")
            return
        }
    }

    func testPointWriteFlowsShiftReportAndInventoryRequest() async throws {
        let shiftPayload = try fixtureData(endpoint: "api/point/shift-report", variant: "success")
        let reqPayload = try fixtureData(endpoint: "api/point/inventory-requests", variant: "success")
        let client = makeClientDynamic { request in
            switch request.url?.path {
            case "/api/point/shift-report":
                return (200, shiftPayload, request.url!)
            case "/api/point/inventory-requests":
                return (200, reqPayload, request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }
        let service = P0ModulesService(apiClient: client)

        try await service.createPointShiftReport(payload: .init(payload: .init(
            date: "2026-04-06",
            operatorId: "o1",
            shift: "day",
            cashAmount: 1000,
            kaspiAmount: 0,
            onlineAmount: 0,
            cardAmount: 0,
            comment: nil
        )))
        try await service.createPointInventoryRequest(payload: .init(payload: .init(
            comment: nil,
            items: [.init(itemId: "it1", requestedQty: 2)]
        )))
    }

    func testPOSReceiptsDecode() async throws {
        let payload = Data("""
        {"ok":true,"data":[{"id":"s1","sale_date":"2026-04-07","total_amount":1500}],"total":1,"page":1,"page_size":20}
        """.utf8)
        let client = makeClient(statusCode: 200, data: payload)
        let service = P0ModulesService(apiClient: client)

        let receipts = try await service.fetchPOSReceipts()

        XCTAssertEqual(receipts.total, 1)
        XCTAssertEqual(receipts.data.first?.id, "s1")
    }

    func testPointReportsDecode() async throws {
        let payload = Data("""
        {"ok":true,"data":{"warehouse":[{"barcode":"111","item_name":"Кола","quantity":2}],"worker_totals":[{"name":"Оператор 1","total_amount":1000}],"client_totals":[{"name":"Клиент 1","total_amount":300}]}}
        """.utf8)
        let client = makeClient(statusCode: 200, data: payload)
        let service = P0ModulesService(apiClient: client)

        let reports = try await service.fetchPointReports()

        XCTAssertEqual(reports.warehouse.count, 1)
        XCTAssertEqual(reports.workerTotals.first?.name, "Оператор 1")
    }

    func testPointInventoryReturnsGetAndPost() async throws {
        var gotGet = false
        var gotPost = false
        let client = makeClientDynamic { request in
            switch (request.httpMethod ?? "GET", request.url?.path ?? "") {
            case ("GET", "/api/point/inventory-returns"):
                gotGet = true
                return (200, Data("""
                {"ok":true,"data":{"returns":[{"id":"r1","total_amount":500}],"sales":[{"id":"s1"}]}}
                """.utf8), request.url!)
            case ("POST", "/api/point/inventory-returns"):
                gotPost = true
                return (200, Data("{\"ok\":true,\"data\":{\"return_id\":\"r1\",\"total_amount\":500}}".utf8), request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }
        let service = P0ModulesService(apiClient: client)

        let returnsData = try await service.fetchPointInventoryReturns()
        try await service.createPointInventoryReturn(payload: .init(payload: .init(
            saleId: "s1",
            returnDate: "2026-04-07",
            shift: "day",
            paymentMethod: "cash",
            cashAmount: 500,
            kaspiAmount: 0,
            itemId: "it1",
            quantity: 1,
            unitPrice: 500
        )))

        XCTAssertTrue(gotGet)
        XCTAssertTrue(gotPost)
        XCTAssertEqual(returnsData.returns.first?.id, "r1")
    }

    func testPOSSaleForbiddenMapsToRU403() async throws {
        let payload = try fixtureData(endpoint: "api/pos/sale", variant: "forbidden")
        let client = makeClient(statusCode: 403, data: payload)
        let service = P0ModulesService(apiClient: client)

        do {
            try await service.createPOSSale(payload: POSSalePayload(
                companyId: "c1", locationId: "l1", items: [.init(itemId: "it1", quantity: 1)],
                cashAmount: 1200, kaspiAmount: 0, onlineAmount: 0, cardAmount: 0, note: nil
            ))
            XCTFail("Expected forbidden")
        } catch {
            XCTAssertEqual(error as? APIError, .forbidden)
            XCTAssertEqual((error as? APIError)?.errorDescription, "Нет доступа для этой роли.")
        }
    }

    @MainActor
    func testStoreWriteFlowsTriggerRefresh() async throws {
        var getCalls = 0
        var postCalls = 0
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            switch (request.httpMethod ?? "GET", path) {
            case ("GET", "/api/admin/inventory/requests"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"requests\":[{\"id\":\"req1\",\"status\":\"pending\"}]}}".utf8), request.url!)
            case ("GET", "/api/admin/store/overview"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"totals\":{\"sku\":1,\"stock_value\":1000}}}".utf8), request.url!)
            case ("GET", "/api/admin/store/receipts"),
                ("GET", "/api/admin/store/writeoffs"),
                ("GET", "/api/admin/store/revisions"),
                ("GET", "/api/admin/store/movements"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"items\":[]}}".utf8), request.url!)
            case ("GET", "/api/admin/store/analytics"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"total_items\":1,\"stock_value\":1000}}".utf8), request.url!)
            case ("GET", "/api/pos/bootstrap"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"companies\":[{\"id\":\"c1\",\"name\":\"Co\"}],\"locations\":[{\"id\":\"l1\",\"name\":\"Loc\",\"company_id\":\"c1\"}],\"items\":[{\"id\":\"it1\",\"name\":\"Item\"}]}}".utf8), request.url!)
            case ("POST", "/api/admin/store/receipts"),
                ("POST", "/api/admin/store/writeoffs"),
                ("POST", "/api/admin/store/revisions"):
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }
        let vm = P0ModulesViewModel(service: P0ModulesService(apiClient: client))
        await vm.loadInventoryAndStore()
        let baselineGetCalls = getCalls

        await vm.createStoreReceipt(locationId: "l1", receivedAt: "2026-04-07", itemId: "it1", quantity: 1, unitCost: 100)
        await vm.createStoreWriteoff(locationId: "l1", writtenAt: "2026-04-07", reason: "test", itemId: "it1", quantity: 1)
        await vm.createStoreRevision(locationId: "l1", countedAt: "2026-04-07", itemId: "it1", actualQty: 1)

        XCTAssertEqual(postCalls, 3)
        XCTAssertGreaterThan(getCalls, baselineGetCalls)
        XCTAssertEqual(vm.successMessage, "Ревизия создана.")
    }

    @MainActor
    func testPointDebtsAndProductsFlowsWithRefresh() async throws {
        var postCalls = 0
        var getCalls = 0
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            switch (request.httpMethod ?? "GET", path) {
            case ("GET", "/api/pos/bootstrap"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"companies\":[],\"locations\":[],\"items\":[]}}".utf8), request.url!)
            case ("GET", "/api/point/bootstrap"):
                getCalls += 1
                return (200, Data("{\"device\":{\"id\":\"d1\",\"name\":\"Point\"},\"companies\":[],\"operators\":[]}".utf8), request.url!)
            case ("GET", "/api/point/debts"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"items\":[]}}".utf8), request.url!)
            case ("GET", "/api/point/products"):
                getCalls += 1
                return (200, Data("{\"ok\":true,\"data\":{\"products\":[{\"id\":\"p1\",\"name\":\"Тест\",\"barcode\":\"1\",\"price\":100}]}}".utf8), request.url!)
            case ("POST", "/api/point/debts"), ("POST", "/api/point/products"):
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }
        let service = P0ModulesService(apiClient: client)
        let vm = P0ModulesViewModel(service: service)
        await vm.loadPOSAndPoint()
        let beforeGets = getCalls

        await vm.createPointDebt(clientName: "Клиент", itemName: "Товар", quantity: 1, unitPrice: 100)
        try await service.createPointProduct(payload: .init(token: "t", payload: .init(name: "Новый", barcode: "2", price: 200, isActive: true)))

        XCTAssertGreaterThan(getCalls, beforeGets)
        XCTAssertGreaterThanOrEqual(postCalls, 2)
    }

    func testDashboard200DecodesKPIAndTrend() async throws {
        let payload = Data(
            """
            {
              "ok": true,
              "data": {
                "today": { "total": 125000, "count": 14, "cash": 35000, "kaspi": 70000, "card": 10000, "online": 10000 },
                "yesterday": { "total": 100000 },
                "change_percent": 25,
                "month_total": 2450000,
                "week_by_day": { "2026-04-01": 120000, "2026-04-02": 125000 }
              }
            }
            """.utf8
        )
        let client = makeClient(statusCode: 200, data: payload)
        let service = AdminContractsService(apiClient: client)

        let dashboard = try await service.loadDashboard()

        XCTAssertEqual(dashboard.today.total, 125000)
        XCTAssertEqual(dashboard.today.count, 14)
        XCTAssertEqual(dashboard.yesterdayTotal, 100000)
        XCTAssertEqual(dashboard.monthTotal, 2450000)
        XCTAssertEqual(dashboard.weekByDay["2026-04-02"], 125000)
    }

    @MainActor
    func testIncomeCreateTriggersListRefresh() async throws {
        var getCalls = 0
        var postCalls = 0
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            if path == "/api/admin/incomes", request.httpMethod == "GET" {
                getCalls += 1
                let body = getCalls == 1
                    ? Data("{\"data\":[]}".utf8)
                    : Data("{\"data\":[{\"id\":\"i2\",\"date\":\"2026-04-07\",\"company_id\":\"c1\",\"operator_id\":\"o1\",\"shift\":\"day\",\"cash_amount\":1000,\"kaspi_amount\":0,\"online_amount\":0,\"card_amount\":0,\"comment\":\"new\"}]}".utf8)
                return (200, body, request.url!)
            }
            if path == "/api/admin/incomes", request.httpMethod == "POST" {
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }
        let service = AdminContractsService(apiClient: client)
        let vm = AdminListModuleViewModel<AdminIncome>(loadAction: service.loadIncomes)

        await vm.load()
        XCTAssertEqual(vm.items.count, 0)

        await vm.runWrite(action: {
            try await service.createIncome(.init(
                date: "2026-04-07",
                companyId: "c1",
                operatorId: "o1",
                shift: "day",
                zone: nil,
                cashAmount: 1000,
                kaspiAmount: 0,
                onlineAmount: 0,
                cardAmount: 0,
                comment: "new"
            ))
        }, successMessage: "Доход создан.")

        XCTAssertEqual(postCalls, 1)
        XCTAssertEqual(getCalls, 2, "Load should be called again after write")
        XCTAssertEqual(vm.items.count, 1)
    }

    @MainActor
    func testExpenseCreateTriggersListRefresh() async throws {
        var getCalls = 0
        var postCalls = 0
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            if path == "/api/admin/expenses", request.httpMethod == "GET" {
                getCalls += 1
                let body = getCalls == 1
                    ? Data("{\"data\":[]}".utf8)
                    : Data("{\"data\":[{\"id\":\"e2\",\"date\":\"2026-04-07\",\"company_id\":\"c1\",\"operator_id\":\"o1\",\"category\":\"Прочее\",\"cash_amount\":500,\"kaspi_amount\":0,\"comment\":\"new\"}]}".utf8)
                return (200, body, request.url!)
            }
            if path == "/api/admin/expenses", request.httpMethod == "POST" {
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }
        let service = AdminContractsService(apiClient: client)
        let vm = AdminListModuleViewModel<AdminExpense>(loadAction: service.loadExpenses)

        await vm.load()
        XCTAssertEqual(vm.items.count, 0)

        await vm.runWrite(action: {
            try await service.createExpense(.init(
                date: "2026-04-07",
                companyId: "c1",
                operatorId: "o1",
                category: "Прочее",
                cashAmount: 500,
                kaspiAmount: 0,
                comment: "new"
            ))
        }, successMessage: "Расход создан.")

        XCTAssertEqual(postCalls, 1)
        XCTAssertEqual(getCalls, 2, "Load should be called again after write")
        XCTAssertEqual(vm.items.count, 1)
    }

    @MainActor
    func testShiftsSaveTriggersWorkflowRefresh() async throws {
        var getCalls = 0
        var postCalls = 0
        let client = makeClientDynamic { request in
            if request.url?.path == "/api/admin/shifts", request.httpMethod == "GET" {
                getCalls += 1
                let count = getCalls == 1 ? 0 : 1
                let body = Data("""
                {"ok":true,"publications":[],"responses":[],"requests":[{"id":"r\(count)"}]}
                """.utf8)
                return (200, body, request.url!)
            }
            if request.url?.path == "/api/admin/shifts", request.httpMethod == "POST" {
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }
        let service = AdminContractsService(apiClient: client)
        let vm = AdminShiftsModuleViewModel(service: service)

        await vm.load()
        XCTAssertEqual(vm.workflow.requests?.count, 1)

        await vm.saveShift(payload: .init(companyId: "c1", date: "2026-04-07", shiftType: "day", operatorName: "Оператор 1", comment: nil))

        XCTAssertEqual(postCalls, 1)
        XCTAssertEqual(getCalls, 2)
    }

    @MainActor
    func testTasksWriteActionsTriggerListRefresh() async throws {
        var getCalls = 0
        var postCalls = 0
        let client = makeClientDynamic { request in
            if request.url?.path == "/api/admin/tasks", request.httpMethod == "GET" {
                getCalls += 1
                let body = getCalls == 1
                    ? Data("{\"data\":[{\"id\":\"t1\",\"title\":\"Задача 1\",\"status\":\"todo\",\"priority\":\"medium\"}]}".utf8)
                    : Data("{\"data\":[{\"id\":\"t1\",\"title\":\"Задача 1\",\"status\":\"in_progress\",\"priority\":\"medium\"}]}".utf8)
                return (200, body, request.url!)
            }
            if request.url?.path == "/api/admin/tasks", request.httpMethod == "POST" {
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }
        let service = AdminContractsService(apiClient: client)
        let vm = AdminListModuleViewModel<AdminTask>(loadAction: service.loadTasks)

        await vm.load()
        XCTAssertEqual(vm.items.first?.status, "todo")

        await vm.runWrite(action: {
            try await service.changeTaskStatus(taskId: "t1", status: "in_progress")
        }, successMessage: "ok")

        XCTAssertEqual(postCalls, 1)
        XCTAssertEqual(getCalls, 2)
        XCTAssertEqual(vm.items.first?.status, "in_progress")
    }

    @MainActor
    func testOperatorsCreateUpdateAndRefresh() async throws {
        var getCalls = 0
        var postCalls = 0
        let client = makeClientDynamic { request in
            if request.url?.path == "/api/admin/operators", request.httpMethod == "GET" {
                getCalls += 1
                let name = getCalls == 1 ? "Оператор Старый" : "Оператор Новый"
                let body = Data("""
                {"data":[{"id":"o1","name":"\(name)","is_active":true}]}
                """.utf8)
                return (200, body, request.url!)
            }
            if request.url?.path == "/api/admin/operators", request.httpMethod == "POST" {
                postCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }
        let service = AdminContractsService(apiClient: client)
        let vm = AdminListModuleViewModel<AdminOperator>(loadAction: service.loadOperators)

        await vm.load()
        XCTAssertEqual(vm.items.first?.name, "Оператор Старый")

        await vm.runWrite(action: {
            try await service.createOperator(.init(name: "Новый", fullName: nil, shortName: nil, position: nil, phone: nil, email: nil))
            try await service.updateOperator(
                operatorId: "o1",
                payload: .init(name: "Оператор Новый", fullName: nil, shortName: nil, position: nil, phone: nil, email: nil)
            )
        }, successMessage: "ok")

        XCTAssertEqual(postCalls, 2)
        XCTAssertEqual(getCalls, 2)
        XCTAssertEqual(vm.items.first?.name, "Оператор Новый")
    }

    @MainActor
    func testCustomersCreateAndHistoryLoad() async throws {
        let historyPayload = Data("""
        {"sales":[{"id":"s1","sale_date":"2026-04-07","total_amount":1400}]}
        """.utf8)
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            if path == "/api/admin/customers", request.httpMethod == "GET" {
                return (200, Data("{\"ok\":true,\"data\":[{\"id\":\"c1\",\"name\":\"Клиент 1\"}]}".utf8), request.url!)
            }
            if path == "/api/admin/customers", request.httpMethod == "POST" {
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            if path == "/api/admin/customers/history", request.httpMethod == "GET" {
                return (200, historyPayload, request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }
        let service = AdminContractsService(apiClient: client)

        let customers = try await service.loadCustomers()
        XCTAssertEqual(customers.count, 1)

        try await service.createCustomer(.init(name: "Клиент 2", phone: nil, cardNumber: nil, email: nil, notes: nil, companyId: nil))
        let sales = try await service.loadCustomerHistory(customerId: "c1")
        XCTAssertEqual(sales.count, 1)
        XCTAssertEqual(sales.first?.id, "s1")
    }

    @MainActor
    func testClientModerationBookingsAndSupportWrite() async throws {
        var bookingsPostCalls = 0
        var supportPostCalls = 0
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            if path == "/api/admin/client/bookings", request.httpMethod == "GET" {
                let body = Data("""
                {"ok":true,"data":[{"id":"b1","customer_name":"Клиент","starts_at":"2026-04-07T09:00:00Z","ends_at":"2026-04-07T10:00:00Z","status":"requested","created_at":"2026-04-07T08:00:00Z"}]}
                """.utf8)
                return (200, body, request.url!)
            }
            if path == "/api/admin/client/bookings", request.httpMethod == "POST" {
                bookingsPostCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            if path == "/api/admin/client/support", request.httpMethod == "GET" {
                let body = Data("""
                {"ok":true,"data":[{"id":"r1","customer_name":"Клиент","status":"new","priority":"normal","message":"Тест","created_at":"2026-04-07T08:00:00Z"}]}
                """.utf8)
                return (200, body, request.url!)
            }
            if path == "/api/admin/client/support", request.httpMethod == "POST" {
                supportPostCalls += 1
                return (200, Data("{\"ok\":true}".utf8), request.url!)
            }
            return (404, Data("{}".utf8), request.url!)
        }

        let bookingsService = AdminClientBookingsService(apiClient: client)
        _ = try await bookingsService.fetchBookings(limit: 25, offset: 0)
        try await bookingsService.setStatus(bookingId: "b1", status: "confirmed")

        let supportService = AdminClientSupportService(apiClient: client)
        _ = try await supportService.fetchTickets(limit: 25, offset: 0)
        try await supportService.setStatus(requestId: "r1", status: "in_progress", priority: "high", assignedStaffId: "staff-1")

        XCTAssertEqual(bookingsPostCalls, 1)
        XCTAssertEqual(supportPostCalls, 1)
    }

    func testMonthlyReportDecodeAndFiltersQuery() async throws {
        var capturedURL: URL?
        let body = Data("""
        {"ok":true,"data":{"daily":[{"date":"2026-04-01","count":2,"total":12000,"cash":4000,"kaspi":5000,"card":2000,"online":1000,"discount":300}],"totals":{"count":2,"total":12000,"cash":4000,"kaspi":5000,"card":2000,"online":1000,"discount":300,"avg_check":6000},"year":2026,"month":4}}
        """.utf8)
        let client = makeClientDynamic { request in
            capturedURL = request.url
            return (200, body, request.url!)
        }
        let service = AdminAnalyticsService(apiClient: client)

        let report = try await service.loadMonthlyReport(year: 2026, month: 4, companyId: "c1")
        XCTAssertEqual(report.daily.count, 1)
        XCTAssertEqual(report.totals.avgCheck, 6000)
        XCTAssertTrue(capturedURL?.absoluteString.contains("year=2026") == true)
        XCTAssertTrue(capturedURL?.absoluteString.contains("month=4") == true)
        XCTAssertTrue(capturedURL?.absoluteString.contains("company_id=c1") == true)
    }

    @MainActor
    func testKPIDashboardDecodeAndTrendModel() async throws {
        let client = makeClientDynamic { request in
            switch request.url?.path {
            case "/api/admin/reports/monthly":
                return (200, Data("{\"ok\":true,\"data\":{\"daily\":[],\"totals\":{\"count\":0,\"total\":0,\"cash\":0,\"kaspi\":0,\"card\":0,\"online\":0,\"discount\":0,\"avg_check\":0},\"year\":2026,\"month\":4}}".utf8), request.url!)
            case "/api/admin/kpi-dashboard":
                return (200, Data("""
                {"collectivePlans":[{"plan_key":"p1","month_start":"2026-04-01","company_code":"arena","turnover_target_month":500000,"turnover_target_week":120000,"is_locked":false}],"weekRows":[{"date":"2026-04-01","cash_amount":1000,"kaspi_amount":500,"card_amount":500},{"date":"2026-04-01","cash_amount":700,"kaspi_amount":0,"card_amount":300}],"monthRows":[],"weekdayShare":{"arena":0.6},"operatorNames":{"o1":"Operator"}}
                """.utf8), request.url!)
            case "/api/goals":
                return (200, Data("{\"data\":[],\"tableExists\":true}".utf8), request.url!)
            case "/api/ai/forecast":
                return (200, Data("{\"text\":\"forecast ok\"}".utf8), request.url!)
            case "/api/analysis/ai":
                return (200, Data("{\"text\":\"analysis ok\"}".utf8), request.url!)
            case "/api/ai/weekly-report":
                return (200, Data("{\"text\":\"weekly ok\"}".utf8), request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }
        let vm = AdminAnalyticsViewModel(service: AdminAnalyticsService(apiClient: client))

        await vm.loadAll()

        XCTAssertEqual(vm.kpi?.collectivePlans.count, 1)
        XCTAssertEqual(vm.kpiTrendPoints.count, 1)
        XCTAssertEqual(vm.kpiTrendPoints.first?.1, 3000)
    }

    @MainActor
    func testForecastAndAnalysisDecodeWithPeriodSwitch() async throws {
        var weeklyCallCount = 0
        let client = makeClientDynamic { request in
            let path = request.url?.path ?? ""
            switch path {
            case "/api/admin/reports/monthly":
                return (200, Data("{\"ok\":true,\"data\":{\"daily\":[],\"totals\":{\"count\":0,\"total\":0,\"cash\":0,\"kaspi\":0,\"card\":0,\"online\":0,\"discount\":0,\"avg_check\":0},\"year\":2026,\"month\":4}}".utf8), request.url!)
            case "/api/admin/kpi-dashboard":
                return (200, Data("{\"collectivePlans\":[],\"weekRows\":[],\"monthRows\":[],\"weekdayShare\":{},\"operatorNames\":{}}".utf8), request.url!)
            case "/api/goals":
                return (200, Data("{\"data\":[],\"tableExists\":true}".utf8), request.url!)
            case "/api/ai/forecast":
                return (200, Data("{\"text\":\"forecast ok\"}".utf8), request.url!)
            case "/api/analysis/ai":
                return (200, Data("{\"text\":\"analysis ok\"}".utf8), request.url!)
            case "/api/ai/weekly-report":
                weeklyCallCount += 1
                return (200, Data("{\"text\":\"weekly \(weeklyCallCount)\"}".utf8), request.url!)
            default:
                return (404, Data("{}".utf8), request.url!)
            }
        }

        let vm = AdminAnalyticsViewModel(service: AdminAnalyticsService(apiClient: client))
        await vm.loadAll()
        let firstWeekly = vm.weeklyReportText

        await vm.switchToPreviousWeek()
        let secondWeekly = vm.weeklyReportText

        XCTAssertEqual(vm.forecastText, "forecast ok")
        XCTAssertEqual(vm.analysisText, "analysis ok")
        XCTAssertNotEqual(firstWeekly, secondWeekly)
    }

    func testForbiddenAnalyticsAccessMapsToRU403() async throws {
        let client = makeClient(statusCode: 403, data: Data("{\"error\":\"forbidden\"}".utf8))
        let service = AdminAnalyticsService(apiClient: client)

        do {
            _ = try await service.loadKPIDashboard(monthStart: "2026-04-01", weekStart: "2026-04-07", weekEnd: "2026-04-13")
            XCTFail("Expected forbidden")
        } catch {
            XCTAssertEqual(error as? APIError, .forbidden)
            XCTAssertEqual((error as? APIError)?.errorDescription, "Нет доступа для этой роли.")
        }
    }

    func testKpiGenerateActionPathSuccess() async throws {
        var method: String?
        var path: String?
        let client = makeClientDynamic { request in
            method = request.httpMethod
            path = request.url?.path
            return (200, Data("{\"ok\":true}".utf8), request.url!)
        }
        let service = AdminAnalyticsService(apiClient: client)
        try await service.generateKPIPlans(monthStart: "2026-04-01")
        XCTAssertEqual(method, "POST")
        XCTAssertEqual(path, "/api/admin/kpi-dashboard")
    }

    func testMarketerForbiddenWriteReturns403RussianMessage() async throws {
        let payload = Data("{\"error\":\"forbidden\"}".utf8)
        let client = makeClient(statusCode: 403, data: payload)
        let service = AdminContractsService(apiClient: client)

        do {
            try await service.createIncome(.init(
                date: "2026-04-07",
                companyId: "c1",
                operatorId: "o1",
                shift: "day",
                zone: nil,
                cashAmount: 1000,
                kaspiAmount: 0,
                onlineAmount: 0,
                cardAmount: 0,
                comment: nil
            ))
            XCTFail("Expected forbidden")
        } catch {
            XCTAssertEqual(error as? APIError, .forbidden)
            XCTAssertEqual((error as? APIError)?.errorDescription, "Нет доступа для этой роли.")
        }
    }

    private func makeClient(statusCode: Int, data: Data) -> APIClient {
        makeClientDynamic { request in
            (statusCode, data, request.url!)
        }
    }

    private func makeClientDynamic(
        responder: @escaping (URLRequest) -> (Int, Data, URL)
    ) -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { request in
            let (statusCode, data, url) = responder(request)
            let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        return APIClient(config: .integrationTest, session: session)
    }

    private func fixtureData(endpoint: String, variant: String) throws -> Data {
        guard
            let endpointMap = fixtureRoot[endpoint] as? [String: Any],
            let value = endpointMap[variant]
        else {
            throw NSError(domain: "fixture", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing fixture \(endpoint).\(variant)"])
        }
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }

    private static func parseFixtureRoot() throws -> [String: Any] {
        let data = try TestFixtureLoader.contractsFixtureJSON()
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "fixture", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid fixture root"])
        }
        return root
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    static func reset() {
        requestHandler = nil
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension AppConfig {
    static var integrationTest: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://www.ordaops.kz")!,
            supabaseURL: URL(string: "https://tmudsqgagblmdctaosgw.supabase.co")!,
            supabaseAnonKey: "test-key"
        )
    }
}
