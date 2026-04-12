import Foundation
import SwiftUI
import Combine

private enum P0APIDateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

protocol P0ModulesServicing {
    func fetchStoreOverview() async throws -> StoreOverviewData
    func fetchInventoryRequests() async throws -> [InventoryRequestItem]
    func decideInventoryRequest(requestId: String, approved: Bool, decisionComment: String?) async throws
    func fetchPOSBootstrap() async throws -> POSBootstrapData
    func fetchPOSReceipts() async throws -> POSReceiptsPage
    func fetchPointBootstrap() async throws -> PointBootstrapData
    func fetchPointReports() async throws -> PointReportsData
    func fetchPointInventoryReturns() async throws -> PointInventoryReturnsData
    func createPOSSale(payload: POSSalePayload) async throws
    func lookupPOSReturn(saleId: String?, shortId: String?) async throws -> POSReturnLookup
    func createPOSReturn(payload: POSReturnPayload) async throws
    func createPointShiftReport(payload: PointShiftReportPayload) async throws
    func createPointInventoryRequest(payload: PointInventoryRequestPayload) async throws
    func fetchStoreReceipts() async throws -> [StoreOperationItem]
    func fetchStoreWriteoffs() async throws -> [StoreOperationItem]
    func fetchStoreRevisions() async throws -> [StoreOperationItem]
    func fetchStoreMovements() async throws -> [StoreOperationItem]
    func fetchStoreAnalytics() async throws -> StoreAnalyticsSummary
    func createStoreReceipt(payload: StoreReceiptRequest) async throws
    func createStoreWriteoff(payload: StoreWriteoffRequest) async throws
    func createStoreRevision(payload: StoreRevisionRequest) async throws
    func createPointInventorySale(payload: PointInventorySaleRequest) async throws
    func createPointInventoryReturn(payload: PointInventoryReturnRequest) async throws
    func fetchPointDebts() async throws -> [PointDebtItem]
    func createPointDebt(payload: PointDebtCreateRequest) async throws
    func deletePointDebt(itemId: String) async throws
    func fetchPointProducts() async throws -> [PointProduct]
    func createPointProduct(payload: PointProductCreateRequest) async throws
    func updatePointProduct(payload: PointProductUpdateRequest) async throws
    func deletePointProduct(productId: String) async throws
}

final class P0ModulesService: P0ModulesServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchStoreOverview() async throws -> StoreOverviewData {
        let endpoint = APIEndpoint(path: "/api/admin/store/overview", method: .GET)
        let envelope: DataEnvelope<StoreOverviewData> = try await apiClient.request(endpoint)
        return envelope.data
    }

    func fetchInventoryRequests() async throws -> [InventoryRequestItem] {
        let endpoint = APIEndpoint(path: "/api/admin/inventory/requests", method: .GET)
        let envelope: InventoryRequestsEnvelope = try await apiClient.request(endpoint)
        return envelope.data.requests
    }

    func decideInventoryRequest(requestId: String, approved: Bool, decisionComment: String?) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/inventory/requests", method: .POST)
        let body = InventoryDecisionRequest(
            action: "decideRequest",
            requestId: requestId,
            approved: approved,
            decisionComment: decisionComment?.isEmpty == true ? nil : decisionComment,
            items: []
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func fetchPOSBootstrap() async throws -> POSBootstrapData {
        let endpoint = APIEndpoint(path: "/api/pos/bootstrap", method: .GET)
        let envelope: DataEnvelope<POSBootstrapData> = try await apiClient.request(endpoint)
        return envelope.data
    }

    func fetchPOSReceipts() async throws -> POSReceiptsPage {
        let endpoint = APIEndpoint(path: "/api/pos/receipts", method: .GET)
        let envelope: POSReceiptsEnvelope = try await apiClient.request(endpoint)
        return POSReceiptsPage(
            data: envelope.data ?? [],
            total: envelope.total ?? 0,
            page: envelope.page ?? 1,
            pageSize: envelope.pageSize ?? 20
        )
    }

    func fetchPointBootstrap() async throws -> PointBootstrapData {
        let endpoint = APIEndpoint(path: "/api/point/bootstrap", method: .GET)
        let envelope: PointBootstrapEnvelope = try await apiClient.request(endpoint)
        return envelope.toData
    }

    func fetchPointReports() async throws -> PointReportsData {
        let endpoint = APIEndpoint(path: "/api/point/reports", method: .GET)
        let envelope: DataEnvelope<PointReportsData> = try await apiClient.request(endpoint)
        return envelope.data
    }

    func fetchPointInventoryReturns() async throws -> PointInventoryReturnsData {
        let endpoint = APIEndpoint(path: "/api/point/inventory-returns", method: .GET)
        let envelope: DataEnvelope<PointInventoryReturnsData> = try await apiClient.request(endpoint)
        return envelope.data
    }

    func createPOSSale(payload: POSSalePayload) async throws {
        let endpoint = APIEndpoint(path: "/api/pos/sale", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func lookupPOSReturn(saleId: String?, shortId: String?) async throws -> POSReturnLookup {
        var endpoint = APIEndpoint(path: "/api/pos/return", method: .GET)
        var items: [URLQueryItem] = []
        if let saleId, !saleId.isEmpty {
            items.append(.init(name: "sale_id", value: saleId))
        }
        if let shortId, !shortId.isEmpty {
            items.append(.init(name: "short_id", value: shortId))
        }
        endpoint.queryItems = items
        let envelope: DataEnvelope<POSReturnLookup> = try await apiClient.request(endpoint)
        return envelope.data
    }

    func createPOSReturn(payload: POSReturnPayload) async throws {
        let endpoint = APIEndpoint(path: "/api/pos/return", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func createPointShiftReport(payload: PointShiftReportPayload) async throws {
        let endpoint = APIEndpoint(path: "/api/point/shift-report", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func createPointInventoryRequest(payload: PointInventoryRequestPayload) async throws {
        let endpoint = APIEndpoint(path: "/api/point/inventory-requests", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func fetchStoreReceipts() async throws -> [StoreOperationItem] {
        let endpoint = APIEndpoint(path: "/api/admin/store/receipts", method: .GET)
        let envelope: DataEnvelope<StoreOperationsData> = try await apiClient.request(endpoint)
        return envelope.data.items
    }

    func fetchStoreWriteoffs() async throws -> [StoreOperationItem] {
        let endpoint = APIEndpoint(path: "/api/admin/store/writeoffs", method: .GET)
        let envelope: DataEnvelope<StoreOperationsData> = try await apiClient.request(endpoint)
        return envelope.data.items
    }

    func fetchStoreRevisions() async throws -> [StoreOperationItem] {
        let endpoint = APIEndpoint(path: "/api/admin/store/revisions", method: .GET)
        let envelope: DataEnvelope<StoreOperationsData> = try await apiClient.request(endpoint)
        return envelope.data.items
    }

    func fetchStoreMovements() async throws -> [StoreOperationItem] {
        let endpoint = APIEndpoint(path: "/api/admin/store/movements", method: .GET)
        let envelope: DataEnvelope<StoreOperationsData> = try await apiClient.request(endpoint)
        return envelope.data.items
    }

    func fetchStoreAnalytics() async throws -> StoreAnalyticsSummary {
        let endpoint = APIEndpoint(path: "/api/admin/store/analytics", method: .GET)
        let envelope: DataEnvelope<StoreAnalyticsSummary> = try await apiClient.request(endpoint)
        return envelope.data
    }

    func createStoreReceipt(payload: StoreReceiptRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/store/receipts", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func createStoreWriteoff(payload: StoreWriteoffRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/store/writeoffs", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func createStoreRevision(payload: StoreRevisionRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/store/revisions", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func createPointInventorySale(payload: PointInventorySaleRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/point/inventory-sales", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func createPointInventoryReturn(payload: PointInventoryReturnRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/point/inventory-returns", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func fetchPointDebts() async throws -> [PointDebtItem] {
        let endpoint = APIEndpoint(path: "/api/point/debts", method: .GET)
        let envelope: DataEnvelope<PointDebtsData> = try await apiClient.request(endpoint)
        return envelope.data.items
    }

    func createPointDebt(payload: PointDebtCreateRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/point/debts", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func deletePointDebt(itemId: String) async throws {
        let endpoint = APIEndpoint(path: "/api/point/debts", method: .POST)
        let body = PointDebtDeleteRequest(action: "deleteDebt", itemId: itemId, operatorId: nil, adminToken: nil)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }

    func fetchPointProducts() async throws -> [PointProduct] {
        let endpoint = APIEndpoint(path: "/api/point/products", method: .GET)
        let envelope: DataEnvelope<PointProductsData> = try await apiClient.request(endpoint)
        return envelope.data.products
    }

    func createPointProduct(payload: PointProductCreateRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/point/products", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func updatePointProduct(payload: PointProductUpdateRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/point/products", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: payload)
    }

    func deletePointProduct(productId: String) async throws {
        let endpoint = APIEndpoint(path: "/api/point/products", method: .POST)
        let body = PointProductDeleteRequest(token: "", productId: productId)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }
}

private struct DataEnvelope<T: Decodable>: Decodable {
    let data: T
}

private struct InventoryRequestsEnvelope: Decodable {
    let data: InventoryRequestsData
}

struct InventoryRequestsData: Decodable {
    let requests: [InventoryRequestItem]
}

struct InventoryRequestItem: Decodable, Identifiable {
    let id: String
    let status: String?
    let companyId: String?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case status
        case companyId = "company_id"
        case createdAt = "created_at"
    }
}

private struct InventoryDecisionRequest: Encodable {
    let action: String
    let requestId: String
    let approved: Bool
    let decisionComment: String?
    let items: [InventoryDecisionItem]
}

private struct InventoryDecisionItem: Encodable {
    let requestItemId: String
    let approvedQty: Double
}

struct StoreOverviewData: Decodable {
    let totals: StoreTotals?
}

struct StoreTotals: Decodable {
    let sku: Int?
    let stockValue: Double?
}

struct POSBootstrapData: Decodable {
    let companies: [POSCompany]
    let locations: [POSLocation]
    let items: [POSItem]
}

struct POSCompany: Decodable, Identifiable {
    let id: String
    let name: String
    let code: String?
}

struct POSLocation: Decodable, Identifiable {
    let id: String
    let name: String
    let companyId: String?
    /// Если бэкенд не шлёт флаг — считаем точку активной (старое поведение).
    let isActive: Bool?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case companyId = "company_id"
        case isActive = "is_active"
    }

    var isActiveResolved: Bool { isActive ?? true }
}

struct POSItem: Decodable, Identifiable {
    let id: String
    let name: String
    let salePrice: Double?
    let totalBalance: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case salePrice = "sale_price"
        case totalBalance = "total_balance"
    }
}

private struct POSReceiptsEnvelope: Decodable {
    let data: [POSReceiptItem]?
    let total: Int?
    let page: Int?
    let pageSize: Int?
}

struct POSReceiptsPage {
    let data: [POSReceiptItem]
    let total: Int
    let page: Int
    let pageSize: Int
}

struct POSReceiptItem: Decodable, Identifiable {
    let id: String
    let saleDate: String?
    let totalAmount: Double?
}

struct POSSalePayload: Encodable {
    let companyId: String
    let locationId: String
    let items: [POSSaleItem]
    let cashAmount: Double
    let kaspiAmount: Double
    let onlineAmount: Double
    let cardAmount: Double
    let note: String?

    private enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
        case locationId = "location_id"
        case items
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case onlineAmount = "online_amount"
        case cardAmount = "card_amount"
        case note
    }
}

struct POSSaleItem: Encodable {
    let itemId: String
    let quantity: Double

    private enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
    }
}

struct POSReturnLookup: Decodable {
    let id: String
    let items: [POSReturnLookupItem]
}

struct POSReturnLookupItem: Decodable, Identifiable {
    let id: String
    let itemId: String
    let quantity: Double
    let unitPrice: Double

    private enum CodingKeys: String, CodingKey {
        case id
        case itemId = "item_id"
        case quantity
        case unitPrice = "unit_price"
    }
}

struct POSReturnPayload: Encodable {
    let saleId: String
    let items: [POSReturnItem]
    let reason: String?

    private enum CodingKeys: String, CodingKey {
        case saleId = "sale_id"
        case items
        case reason
    }
}

struct POSReturnItem: Encodable {
    let itemId: String
    let quantity: Double
    let unitPrice: Double

    private enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case quantity
        case unitPrice = "unit_price"
    }
}

private struct PointBootstrapEnvelope: Decodable {
    let company: POSCompany?
    let companies: [POSCompany]?
    let operators: [PointOperator]?
    let device: PointDevice?

    var toData: PointBootstrapData {
        PointBootstrapData(
            company: company,
            companies: companies ?? [],
            operators: operators ?? [],
            device: device
        )
    }
}

struct PointBootstrapData {
    let company: POSCompany?
    let companies: [POSCompany]
    let operators: [PointOperator]
    let device: PointDevice?
}

struct PointOperator: Decodable, Identifiable {
    let id: String
    let name: String
    let roleInCompany: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case roleInCompany = "role_in_company"
    }
}

struct PointDevice: Decodable {
    let id: String
    let name: String
    let pointMode: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case pointMode = "point_mode"
    }
}

struct PointShiftReportPayload: Encodable {
    let action: String = "createShiftReport"
    let payload: PointShiftReportBody
}

struct PointShiftReportBody: Encodable {
    let date: String
    let operatorId: String
    let shift: String
    let cashAmount: Double
    let kaspiAmount: Double
    let onlineAmount: Double
    let cardAmount: Double
    let comment: String?

    private enum CodingKeys: String, CodingKey {
        case date
        case operatorId = "operator_id"
        case shift
        case cashAmount = "cash_amount"
        case kaspiAmount = "kaspi_amount"
        case onlineAmount = "online_amount"
        case cardAmount = "card_amount"
        case comment
    }
}

struct PointInventoryRequestPayload: Encodable {
    let action: String = "createRequest"
    let payload: PointInventoryRequestBody
}

struct PointInventoryRequestBody: Encodable {
    let comment: String?
    let items: [PointInventoryRequestItem]
}

struct PointInventoryRequestItem: Encodable {
    let itemId: String
    let requestedQty: Double

    private enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case requestedQty = "requested_qty"
    }
}

struct StoreOperationItem: Decodable, Identifiable {
    let id: String
    let createdAt: String?
    let status: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case status
    }
}

struct StoreOperationsData: Decodable {
    let items: [StoreOperationItem]

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let arr = try? c.decode([StoreOperationItem].self) {
            items = arr
            return
        }
        let keyed = try decoder.container(keyedBy: DynamicCodingKeys.self)
        let keys = ["receipts", "writeoffs", "revisions", "movements", "items", "rows", "data"]
        for k in keys {
            let key = DynamicCodingKeys(stringValue: k)!
            if let arr = try? keyed.decode([StoreOperationItem].self, forKey: key) {
                items = arr
                return
            }
        }
        items = []
    }
}

struct StoreAnalyticsSummary: Decodable {
    let stockValue: Double?
    let totalItems: Int?

    init(from decoder: Decoder) throws {
        let keyed = try decoder.container(keyedBy: DynamicCodingKeys.self)
        stockValue = (try? keyed.decode(Double.self, forKey: .init(stringValue: "stockValue")!))
            ?? (try? keyed.decode(Double.self, forKey: .init(stringValue: "stock_value")!))
        totalItems = (try? keyed.decode(Int.self, forKey: .init(stringValue: "totalItems")!))
            ?? (try? keyed.decode(Int.self, forKey: .init(stringValue: "total_items")!))
            ?? (try? keyed.decode(Int.self, forKey: .init(stringValue: "sku")!))
    }
}

private struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    init?(stringValue: String) { self.stringValue = stringValue }
    var intValue: Int? { nil }
    init?(intValue: Int) { nil }
}

struct StoreReceiptRequest: Encodable {
    let action: String = "createReceipt"
    let payload: StoreReceiptBody
}

struct StoreReceiptBody: Encodable {
    let locationId: String
    let receivedAt: String
    let itemId: String
    let quantity: Double
    let unitCost: Double

    private enum CodingKeys: String, CodingKey {
        case locationId = "location_id"
        case receivedAt = "received_at"
        case itemId = "item_id"
        case quantity
        case unitCost = "unit_cost"
    }

    func encode(to encoder: Encoder) throws {
        struct ItemPayload: Encodable {
            let itemId: String
            let quantity: Double
            let unitCost: Double
            private enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case quantity
                case unitCost = "unit_cost"
            }
        }
        var c = encoder.container(keyedBy: DynamicCodingKeys.self)
        try c.encode(locationId, forKey: .init(stringValue: "location_id")!)
        try c.encode(receivedAt, forKey: .init(stringValue: "received_at")!)
        try c.encode([ItemPayload(itemId: itemId, quantity: quantity, unitCost: unitCost)], forKey: .init(stringValue: "items")!)
    }
}

struct StoreWriteoffRequest: Encodable {
    let action: String = "createWriteoff"
    let payload: StoreWriteoffBody
}

struct StoreWriteoffBody: Encodable {
    let locationId: String
    let writtenAt: String
    let reason: String
    let itemId: String
    let quantity: Double

    func encode(to encoder: Encoder) throws {
        struct ItemPayload: Encodable {
            let itemId: String
            let quantity: Double
            private enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case quantity
            }
        }
        var c = encoder.container(keyedBy: DynamicCodingKeys.self)
        try c.encode(locationId, forKey: .init(stringValue: "location_id")!)
        try c.encode(writtenAt, forKey: .init(stringValue: "written_at")!)
        try c.encode(reason, forKey: .init(stringValue: "reason")!)
        try c.encode([ItemPayload(itemId: itemId, quantity: quantity)], forKey: .init(stringValue: "items")!)
    }
}

struct StoreRevisionRequest: Encodable {
    let action: String = "createRevision"
    let payload: StoreRevisionBody
}

struct StoreRevisionBody: Encodable {
    let locationId: String
    let countedAt: String
    let itemId: String
    let actualQty: Double

    func encode(to encoder: Encoder) throws {
        struct ItemPayload: Encodable {
            let itemId: String
            let actualQty: Double
            private enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case actualQty = "actual_qty"
            }
        }
        var c = encoder.container(keyedBy: DynamicCodingKeys.self)
        try c.encode(locationId, forKey: .init(stringValue: "location_id")!)
        try c.encode(countedAt, forKey: .init(stringValue: "counted_at")!)
        try c.encode([ItemPayload(itemId: itemId, actualQty: actualQty)], forKey: .init(stringValue: "items")!)
    }
}

struct PointInventorySaleRequest: Encodable {
    let action: String = "createSale"
    let payload: PointInventorySaleBody
}

struct PointInventorySaleBody: Encodable {
    let saleDate: String
    let shift: String
    let paymentMethod: String
    let itemId: String
    let quantity: Double
    let unitPrice: Double

    func encode(to encoder: Encoder) throws {
        struct ItemPayload: Encodable {
            let itemId: String
            let quantity: Double
            let unitPrice: Double
            private enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case quantity
                case unitPrice = "unit_price"
            }
        }
        var c = encoder.container(keyedBy: DynamicCodingKeys.self)
        try c.encode(saleDate, forKey: .init(stringValue: "sale_date")!)
        try c.encode(shift, forKey: .init(stringValue: "shift")!)
        try c.encode(paymentMethod, forKey: .init(stringValue: "payment_method")!)
        try c.encode([ItemPayload(itemId: itemId, quantity: quantity, unitPrice: unitPrice)], forKey: .init(stringValue: "items")!)
    }
}

struct PointInventoryReturnRequest: Encodable {
    let action: String = "createReturn"
    let payload: PointInventoryReturnBody
}

struct PointInventoryReturnBody: Encodable {
    let saleId: String
    let returnDate: String
    let shift: String
    let paymentMethod: String
    let cashAmount: Double?
    let kaspiAmount: Double?
    let itemId: String
    let quantity: Double
    let unitPrice: Double

    func encode(to encoder: Encoder) throws {
        struct ItemPayload: Encodable {
            let itemId: String
            let quantity: Double
            let unitPrice: Double
            private enum CodingKeys: String, CodingKey {
                case itemId = "item_id"
                case quantity
                case unitPrice = "unit_price"
            }
        }
        var c = encoder.container(keyedBy: DynamicCodingKeys.self)
        try c.encode(saleId, forKey: .init(stringValue: "sale_id")!)
        try c.encode(returnDate, forKey: .init(stringValue: "return_date")!)
        try c.encode(shift, forKey: .init(stringValue: "shift")!)
        try c.encode(paymentMethod, forKey: .init(stringValue: "payment_method")!)
        try c.encode(cashAmount ?? 0, forKey: .init(stringValue: "cash_amount")!)
        try c.encode(kaspiAmount ?? 0, forKey: .init(stringValue: "kaspi_amount")!)
        try c.encode([ItemPayload(itemId: itemId, quantity: quantity, unitPrice: unitPrice)], forKey: .init(stringValue: "items")!)
    }
}

struct PointInventoryReturnsData: Decodable {
    let returns: [PointReturnEntry]
    let sales: [PointReturnSale]
}

struct PointReturnEntry: Decodable, Identifiable {
    let id: String
    let totalAmount: Double?
}

struct PointReturnSale: Decodable, Identifiable {
    let id: String
}

struct PointReportsData: Decodable {
    let warehouse: [PointWarehouseRow]
    let workerTotals: [PointNamedTotal]
    let clientTotals: [PointNamedTotal]
}

struct PointWarehouseRow: Decodable, Identifiable {
    let barcode: String?
    let itemName: String
    let quantity: Double
    var id: String { "\(barcode ?? "—")-\(itemName)" }
}

struct PointNamedTotal: Decodable, Identifiable {
    let name: String
    let totalAmount: Double
    var id: String { name }
}

struct PointDebtItem: Decodable, Identifiable {
    let id: String
    let debtorName: String?
    let itemName: String?
    let totalAmount: Double?

    private enum CodingKeys: String, CodingKey {
        case id
        case debtorName = "debtor_name"
        case itemName = "item_name"
        case totalAmount = "total_amount"
    }
}

struct PointDebtsData: Decodable {
    let items: [PointDebtItem]
}

struct PointDebtCreateRequest: Encodable {
    let action: String = "createDebt"
    let payload: PointDebtCreateBody
}

struct PointDebtCreateBody: Encodable {
    let clientName: String
    let itemName: String
    let quantity: Double
    let unitPrice: Double

    private enum CodingKeys: String, CodingKey {
        case clientName = "client_name"
        case itemName = "item_name"
        case quantity
        case unitPrice = "unit_price"
    }
}

struct PointDebtDeleteRequest: Encodable {
    let action: String
    let itemId: String
    let operatorId: String?
    let adminToken: String?

    private enum CodingKeys: String, CodingKey {
        case action
        case itemId
        case operatorId
        case adminToken
    }
}

struct PointProduct: Decodable, Identifiable {
    let id: String
    let name: String
    let barcode: String?
    let price: Double?
}

struct PointProductsData: Decodable {
    let products: [PointProduct]
}

struct PointProductCreateRequest: Encodable {
    let action: String = "createProduct"
    let token: String
    let payload: PointProductPayload
}

struct PointProductUpdateRequest: Encodable {
    let action: String = "updateProduct"
    let token: String
    let productId: String
    let payload: PointProductPayload
}

struct PointProductDeleteRequest: Encodable {
    let token: String
    let productId: String

    let action: String = "deleteProduct"
}

struct PointProductPayload: Encodable {
    let name: String
    let barcode: String
    let price: Double
    let isActive: Bool

    private enum CodingKeys: String, CodingKey {
        case name
        case barcode
        case price
        case isActive = "is_active"
    }
}

@MainActor
final class P0ModulesViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var inventoryRequests: [InventoryRequestItem] = []
    @Published var storeOverview: StoreOverviewData?
    @Published var posBootstrap: POSBootstrapData?
    @Published var posReceipts: POSReceiptsPage?
    @Published var pointBootstrap: PointBootstrapData?
    @Published var pointReports: PointReportsData?
    @Published var pointInventoryReturns: PointInventoryReturnsData?
    @Published var returnLookup: POSReturnLookup?
    @Published var storeReceipts: [StoreOperationItem] = []
    @Published var storeWriteoffs: [StoreOperationItem] = []
    @Published var storeRevisions: [StoreOperationItem] = []
    @Published var storeMovements: [StoreOperationItem] = []
    @Published var storeAnalytics: StoreAnalyticsSummary?
    @Published var pointDebts: [PointDebtItem] = []
    @Published var pointProducts: [PointProduct] = []
    /// Point API routes require `x-point-device-token`; staff-only session cannot load them — warn without blocking POS.
    @Published var pointTerminalWarning: String?

    private let service: P0ModulesServicing

    init(service: P0ModulesServicing) {
        self.service = service
    }

    func loadInventoryAndStore() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let requests = service.fetchInventoryRequests()
            async let overview = service.fetchStoreOverview()
            async let receipts = service.fetchStoreReceipts()
            async let writeoffs = service.fetchStoreWriteoffs()
            async let revisions = service.fetchStoreRevisions()
            async let movements = service.fetchStoreMovements()
            async let analytics = service.fetchStoreAnalytics()
            inventoryRequests = try await requests
            storeOverview = try await overview
            storeReceipts = try await receipts
            storeWriteoffs = try await writeoffs
            storeRevisions = try await revisions
            storeMovements = try await movements
            storeAnalytics = try await analytics
            if let pos = try? await service.fetchPOSBootstrap() {
                posBootstrap = pos
            }
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func decide(requestId: String, approved: Bool, comment: String?) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.decideInventoryRequest(requestId: requestId, approved: approved, decisionComment: comment)
            successMessage = approved ? "Заявка одобрена." : "Заявка отклонена."
            await loadInventoryAndStore()
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func loadPOSAndPoint() async {
        isLoading = true
        errorMessage = nil
        pointTerminalWarning = nil
        defer { isLoading = false }
        do {
            async let pos = service.fetchPOSBootstrap()
            async let posReceipts = service.fetchPOSReceipts()
            posBootstrap = try await pos
            self.posReceipts = try await posReceipts
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
            posBootstrap = nil
            self.posReceipts = nil
            clearPointPayload()
            return
        }
        do {
            async let point = service.fetchPointBootstrap()
            async let pointReports = service.fetchPointReports()
            async let pointReturns = service.fetchPointInventoryReturns()
            async let debts = service.fetchPointDebts()
            async let products = service.fetchPointProducts()
            pointBootstrap = try await point
            self.pointReports = try await pointReports
            self.pointInventoryReturns = try await pointReturns
            pointDebts = try await debts
            pointProducts = try await products
            pointTerminalWarning = nil
        } catch {
            clearPointPayload()
            pointTerminalWarning = APIErrorMapper().map(error: error).errorDescription
        }
    }

    private func clearPointPayload() {
        pointBootstrap = nil
        pointReports = nil
        pointInventoryReturns = nil
        pointDebts = []
        pointProducts = []
    }

    func createSale(
        companyId: String,
        locationId: String,
        itemId: String,
        quantity: Double,
        cash: Double,
        kaspi: Double,
        online: Double,
        card: Double,
        note: String?
    ) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPOSSale(payload: POSSalePayload(
                companyId: companyId,
                locationId: locationId,
                items: [.init(itemId: itemId, quantity: quantity)],
                cashAmount: cash,
                kaspiAmount: kaspi,
                onlineAmount: online,
                cardAmount: card,
                note: note
            ))
            successMessage = "Продажа успешно проведена."
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func lookupReturn(saleId: String?, shortId: String?) async {
        errorMessage = nil
        do {
            returnLookup = try await service.lookupPOSReturn(saleId: saleId, shortId: shortId)
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func createReturn(saleId: String, itemId: String, quantity: Double, unitPrice: Double, reason: String?) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPOSReturn(payload: POSReturnPayload(
                saleId: saleId,
                items: [.init(itemId: itemId, quantity: quantity, unitPrice: unitPrice)],
                reason: reason
            ))
            successMessage = "Возврат успешно создан."
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func createPointShiftReport(date: String, operatorId: String, shift: String, cash: Double, kaspi: Double, online: Double, card: Double, comment: String?) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPointShiftReport(payload: .init(payload: .init(
                date: date,
                operatorId: operatorId,
                shift: shift,
                cashAmount: cash,
                kaspiAmount: kaspi,
                onlineAmount: online,
                cardAmount: card,
                comment: comment
            )))
            successMessage = "Сменный отчет отправлен."
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func createPointInventoryRequest(itemId: String, requestedQty: Double, comment: String?) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPointInventoryRequest(payload: .init(payload: .init(
                comment: comment,
                items: [.init(itemId: itemId, requestedQty: requestedQty)]
            )))
            successMessage = "Заявка точки отправлена."
        } catch {
            errorMessage = APIErrorMapper().map(error: error).errorDescription
        }
    }

    func createStoreReceipt(locationId: String, receivedAt: String, itemId: String, quantity: Double, unitCost: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createStoreReceipt(payload: .init(payload: .init(
                locationId: locationId, receivedAt: receivedAt, itemId: itemId, quantity: quantity, unitCost: unitCost
            )))
            successMessage = "Приемка создана."
            await loadInventoryAndStore()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func createStoreWriteoff(locationId: String, writtenAt: String, reason: String, itemId: String, quantity: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createStoreWriteoff(payload: .init(payload: .init(
                locationId: locationId, writtenAt: writtenAt, reason: reason, itemId: itemId, quantity: quantity
            )))
            successMessage = "Списание создано."
            await loadInventoryAndStore()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func createStoreRevision(locationId: String, countedAt: String, itemId: String, actualQty: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createStoreRevision(payload: .init(payload: .init(
                locationId: locationId, countedAt: countedAt, itemId: itemId, actualQty: actualQty
            )))
            successMessage = "Ревизия создана."
            await loadInventoryAndStore()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func createPointInventorySale(date: String, shift: String, payment: String, itemId: String, quantity: Double, unitPrice: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPointInventorySale(payload: .init(payload: .init(
                saleDate: date, shift: shift, paymentMethod: payment, itemId: itemId, quantity: quantity, unitPrice: unitPrice
            )))
            successMessage = "Продажа точки создана."
            await loadPOSAndPoint()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func createPointInventoryReturn(saleId: String, date: String, shift: String, payment: String, itemId: String, quantity: Double, unitPrice: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPointInventoryReturn(payload: .init(payload: .init(
                saleId: saleId,
                returnDate: date,
                shift: shift,
                paymentMethod: payment,
                cashAmount: payment == "cash" ? unitPrice * quantity : 0,
                kaspiAmount: payment == "kaspi" ? unitPrice * quantity : 0,
                itemId: itemId,
                quantity: quantity,
                unitPrice: unitPrice
            )))
            successMessage = "Возврат точки создан."
            await loadPOSAndPoint()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func createPointDebt(clientName: String, itemName: String, quantity: Double, unitPrice: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPointDebt(payload: .init(payload: .init(
                clientName: clientName, itemName: itemName, quantity: quantity, unitPrice: unitPrice
            )))
            successMessage = "Долг точки создан."
            await loadPOSAndPoint()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func deletePointDebt(itemId: String) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.deletePointDebt(itemId: itemId)
            successMessage = "Долг удален."
            await loadPOSAndPoint()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func createPointProduct(name: String, barcode: String, price: Double) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.createPointProduct(payload: .init(
                token: "",
                payload: .init(
                    name: name,
                    barcode: barcode,
                    price: price,
                    isActive: true
                )
            ))
            successMessage = "Товар точки создан."
            await loadPOSAndPoint()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }

    func deletePointProduct(productId: String) async {
        errorMessage = nil
        successMessage = nil
        do {
            try await service.deletePointProduct(productId: productId)
            successMessage = "Товар удален."
            await loadPOSAndPoint()
        } catch { errorMessage = APIErrorMapper().map(error: error).errorDescription }
    }
}

struct P0ModulesHubView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    private var capabilities: Set<AppCapability> {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext)
    }

    private var service: P0ModulesServicing {
        P0ModulesService(apiClient: sessionStore.apiClient)
    }

    var body: some View {
        List {
            if capabilities.contains(.adminInventoryRead) || capabilities.contains(.adminStoreRead) {
                NavigationLink("Склад и магазин") {
                    InventoryStoreModuleView(service: service)
                }
            }
            if capabilities.contains(.adminPOSRead) || capabilities.contains(.adminPointRead) {
                NavigationLink("POS и Point Terminal") {
                    POSPointModuleView(service: service)
                }
            }
        }
        .navigationTitle("Склад и точка")
    }
}

struct InventoryStoreModuleView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: P0ModulesViewModel
    @State private var decisionComment = ""
    @State private var storeCompanyId = ""
    @State private var storeLocationId = ""
    @State private var storeOperationDate = Date()
    @State private var storeItemId = ""
    @State private var storeQty = "1"
    @State private var storeCost = "0"
    @State private var writeoffReason = "Списание"

    init(service: P0ModulesServicing) {
        _vm = StateObject(wrappedValue: P0ModulesViewModel(service: service))
    }

    private var canWrite: Bool {
        let c = CapabilityMatrix.capabilities(for: sessionStore.roleContext)
        return c.contains(.adminInventoryWrite) || c.contains(.adminStoreWrite)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppTheme.Spacing.md) {
                if vm.isLoading {
                    LoadingStateView(message: "Загрузка...")
                } else if let error = vm.errorMessage {
                    ErrorStateView(message: error, retryAction: { Task { await vm.loadInventoryAndStore() } })
                } else {
                    storeOverviewCard
                    storePulseCard
                    storeOperationsCard
                    storeRequestsCard
                    storeActionsCard
                }
            }
            .padding(AppTheme.Spacing.md)
        }
        .background(AppTheme.Colors.bgPrimary.ignoresSafeArea())
        .navigationTitle("Склад и магазин")
        .task {
            await vm.loadInventoryAndStore()
            if storeCompanyId.isEmpty { storeCompanyId = vm.posBootstrap?.companies.first?.id ?? "" }
            if storeLocationId.isEmpty {
                storeLocationId = (vm.posBootstrap?.locations.first { $0.companyId == storeCompanyId }?.id)
                    ?? vm.posBootstrap?.locations.first?.id
                    ?? ""
            }
            if storeItemId.isEmpty { storeItemId = vm.posBootstrap?.items.first?.id ?? "" }
        }
    }

    private var storeOverviewCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Обзор склада", icon: "shippingbox.fill", iconColor: AppTheme.Colors.accentBlue)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "SKU", value: "\(vm.storeOverview?.totals?.sku ?? 0)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ОСТАТКИ", value: MoneyFormatter.short(vm.storeOverview?.totals?.stockValue ?? 0), color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "ПОЗИЦИЙ", value: "\(vm.storeAnalytics?.totalItems ?? 0)", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
                StatTile(title: "АНАЛИТИКА", value: MoneyFormatter.short(vm.storeAnalytics?.stockValue ?? 0), color: AppTheme.Colors.purple, bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder)
            }
        }
        .appCard()
    }

    private var storeOperationsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            SectionHeader(title: "Операции склада", icon: "arrow.left.arrow.right.square", iconColor: AppTheme.Colors.accentPrimary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.sm) {
                StatTile(title: "ПРИЕМКИ", value: "\(vm.storeReceipts.count)", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder)
                StatTile(title: "СПИСАНИЯ", value: "\(vm.storeWriteoffs.count)", color: AppTheme.Colors.error, bgColor: AppTheme.Colors.errorBg, borderColor: AppTheme.Colors.errorBorder)
                StatTile(title: "РЕВИЗИИ", value: "\(vm.storeRevisions.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder)
                StatTile(title: "ДВИЖЕНИЯ", value: "\(vm.storeMovements.count)", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder)
            }
        }
        .appCard()
    }

    private var storePulseCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Пульс склада", icon: "waveform.path.ecg", iconColor: AppTheme.Colors.warning)
            let latest = latestStoreOperations
            if latest.isEmpty {
                Text("Операций пока нет")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(Array(latest.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: operationIcon(row.kind))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(operationColor(row.kind))
                            .frame(width: 28, height: 28)
                            .background(operationColor(row.kind).opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(operationTitle(row.kind))
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(row.createdAt?.prefix(10) ?? "—")
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        Spacer()
                        StatusBadge(text: (row.status ?? "pending").uppercased(), style: operationStatusStyle(row.status))
                    }
                    if index < latest.count - 1 {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            }
        }
        .appCard()
    }

    private var storeRequestsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Заявки склада", icon: "tray.full.fill", iconColor: AppTheme.Colors.purple)
            if vm.inventoryRequests.isEmpty {
                EmptyStateView(message: "Пока нет заявок")
            } else {
                ForEach(vm.inventoryRequests) { req in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Заявка \(shortId(req.id))")
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Spacer()
                            StatusBadge(text: (req.status ?? "pending").uppercased(), style: .info)
                        }
                        if canWrite {
                            HStack {
                                Button("Одобрить") { Task { await vm.decide(requestId: req.id, approved: true, comment: decisionComment) } }
                                    .buttonStyle(GhostButtonStyle())
                                Button("Отклонить") { Task { await vm.decide(requestId: req.id, approved: false, comment: decisionComment) } }
                                    .buttonStyle(GhostButtonStyle())
                            }
                        }
                    }
                    if req.id != vm.inventoryRequests.last?.id {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            }
        }
        .appCard()
    }

    private var storeActionsCard: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            SectionHeader(title: "Действия", icon: "plus.circle.fill", iconColor: AppTheme.Colors.accentBlue)
            TextField("Комментарий решения", text: $decisionComment).appInputStyle()
            Picker("Компания", selection: $storeCompanyId) {
                Text("Выберите компанию").tag("")
                ForEach(vm.posBootstrap?.companies ?? []) { company in
                    Text(company.name).tag(company.id)
                }
            }
            .pickerStyle(.menu)
            Picker("Локация", selection: $storeLocationId) {
                Text("Выберите локацию").tag("")
                ForEach((vm.posBootstrap?.locations ?? []).filter { loc in
                    storeCompanyId.isEmpty || loc.companyId == storeCompanyId
                }) { location in
                    Text(location.name).tag(location.id)
                }
            }
            .pickerStyle(.menu)
            DatePicker("Дата операции", selection: $storeOperationDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ru_RU"))
            Picker("Товар", selection: $storeItemId) {
                Text("Выберите товар").tag("")
                ForEach(vm.posBootstrap?.items ?? []) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Количество", text: $storeQty).keyboardType(.decimalPad).appInputStyle()
            TextField("Цена за единицу", text: $storeCost).keyboardType(.decimalPad).appInputStyle()
            TextField("Причина списания", text: $writeoffReason).appInputStyle()
            HStack {
                Button("Приемка") { createStoreReceipt() }.buttonStyle(PrimaryButtonStyle())
                Button("Списание") { createStoreWriteoff() }.buttonStyle(GhostButtonStyle())
                Button("Ревизия") { createStoreRevision() }.buttonStyle(GhostButtonStyle())
            }
            if !canWrite {
                AlertBanner(message: "Нет доступа для этой роли.", style: .critical)
            }
            if let success = vm.successMessage {
                AlertBanner(message: success, style: .info)
            }
        }
        .appCard()
    }

    private func shortId(_ id: String) -> String {
        if id.count <= 10 { return id }
        return String(id.prefix(8)) + "…"
    }

    private typealias StoreOpKindRow = (kind: String, item: StoreOperationItem)

    private var latestStoreOperations: [(id: String, kind: String, status: String?, createdAt: String?)] {
        let rows: [StoreOpKindRow] =
            vm.storeReceipts.map { ("receipt", $0) } +
            vm.storeWriteoffs.map { ("writeoff", $0) } +
            vm.storeRevisions.map { ("revision", $0) } +
            vm.storeMovements.map { ("movement", $0) }

        return rows
            .sorted { ($0.item.createdAt ?? "") > ($1.item.createdAt ?? "") }
            .prefix(6)
            .map { row in
                (id: row.item.id, kind: row.kind, status: row.item.status, createdAt: row.item.createdAt)
            }
    }

    private func operationTitle(_ kind: String) -> String {
        switch kind {
        case "receipt": return "Приемка"
        case "writeoff": return "Списание"
        case "revision": return "Ревизия"
        case "movement": return "Движение"
        default: return "Операция"
        }
    }

    private func operationIcon(_ kind: String) -> String {
        switch kind {
        case "receipt": return "tray.and.arrow.down.fill"
        case "writeoff": return "trash.fill"
        case "revision": return "checkmark.seal.fill"
        case "movement": return "arrow.left.arrow.right.circle.fill"
        default: return "shippingbox.fill"
        }
    }

    private func operationColor(_ kind: String) -> Color {
        switch kind {
        case "receipt": return AppTheme.Colors.success
        case "writeoff": return AppTheme.Colors.error
        case "revision": return AppTheme.Colors.info
        case "movement": return AppTheme.Colors.warning
        default: return AppTheme.Colors.textMuted
        }
    }

    private func operationStatusStyle(_ status: String?) -> StatusBadge.Style {
        switch (status ?? "").lowercased() {
        case "done", "approved", "completed": return .excellent
        case "rejected", "failed", "cancelled": return .critical
        case "pending", "draft", "new": return .warning
        default: return .info
        }
    }

    private func createStoreReceipt() {
        guard canWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
        guard !storeLocationId.isEmpty, !storeItemId.isEmpty else {
            vm.errorMessage = "Выберите локацию и товар."
            return
        }
        Task {
            let day = P0APIDateFormatter.yyyyMMdd.string(from: storeOperationDate)
            await vm.createStoreReceipt(
                locationId: storeLocationId,
                receivedAt: day,
                itemId: storeItemId,
                quantity: Double(storeQty) ?? 0,
                unitCost: Double(storeCost) ?? 0
            )
        }
    }

    private func createStoreWriteoff() {
        guard canWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
        guard !storeLocationId.isEmpty, !storeItemId.isEmpty else {
            vm.errorMessage = "Выберите локацию и товар."
            return
        }
        Task {
            let day = P0APIDateFormatter.yyyyMMdd.string(from: storeOperationDate)
            await vm.createStoreWriteoff(
                locationId: storeLocationId,
                writtenAt: day,
                reason: writeoffReason,
                itemId: storeItemId,
                quantity: Double(storeQty) ?? 0
            )
        }
    }

    private func createStoreRevision() {
        guard canWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
        guard !storeLocationId.isEmpty, !storeItemId.isEmpty else {
            vm.errorMessage = "Выберите локацию и товар."
            return
        }
        Task {
            let day = P0APIDateFormatter.yyyyMMdd.string(from: storeOperationDate)
            await vm.createStoreRevision(
                locationId: storeLocationId,
                countedAt: day,
                itemId: storeItemId,
                actualQty: Double(storeQty) ?? 0
            )
        }
    }
}

struct POSPointModuleView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var vm: P0ModulesViewModel
    @State private var posCompanyId = ""
    @State private var posLocationId = ""
    @State private var posItemId = ""
    @State private var posQuantity = "1"
    @State private var posCash = "0"
    @State private var posKaspi = "0"
    @State private var posOnline = "0"
    @State private var posCard = "0"
    @State private var posNote = ""
    @State private var returnSaleId = ""
    @State private var returnShortId = ""
    @State private var returnItemId = ""
    @State private var returnQty = "1"
    @State private var returnUnitPrice = "0"
    @State private var returnReason = ""
    @State private var shiftOperationDate = Date()
    @State private var shiftOperatorId = ""
    @State private var shiftType = "day"
    @State private var shiftCash = "0"
    @State private var shiftKaspi = "0"
    @State private var shiftOnline = "0"
    @State private var shiftCard = "0"
    @State private var shiftComment = ""
    @State private var requestItemId = ""
    @State private var requestQty = "1"
    @State private var requestComment = ""
    @State private var pointSaleOperationDate = Date()
    @State private var pointSaleShift = "day"
    @State private var pointSalePayment = "cash"
    @State private var pointSaleItemId = ""
    @State private var pointSaleQty = "1"
    @State private var pointSaleUnitPrice = "0"
    @State private var pointReturnOperationDate = Date()
    @State private var pointReturnShift = "day"
    @State private var pointReturnPayment = "cash"
    @State private var pointReturnSaleId = ""
    @State private var pointReturnItemId = ""
    @State private var pointReturnQty = "1"
    @State private var pointReturnPrice = "0"
    @State private var debtClientName = ""
    @State private var debtItemName = ""
    @State private var debtQty = "1"
    @State private var debtPrice = "0"
    @State private var debtDeleteId = ""
    @State private var debtSearchQuery = ""
    @State private var productName = ""
    @State private var productBarcode = ""
    @State private var productPrice = "0"
    @State private var productDeleteId = ""
    @State private var activeOpsFilter: OpsFilter?
    @State private var drilldownPrefillMessage: String?
    @State private var scrollTarget: String?

    init(service: P0ModulesServicing) {
        _vm = StateObject(wrappedValue: P0ModulesViewModel(service: service))
    }

    var body: some View {
        Group {
            if vm.isLoading { LoadingStateView(message: "Загрузка...") }
            else if let error = vm.errorMessage, vm.posBootstrap == nil {
                ErrorStateView(message: error, retryAction: { Task { await vm.loadPOSAndPoint() } })
            }
            else {
                ScrollViewReader { proxy in
                    List {
                        if let warn = vm.pointTerminalWarning {
                            Section {
                                AlertBanner(message: warn, style: .warning)
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                        }
                        posCatalogSection
                        pointCatalogSection
                        opsDrilldownSection
                        pointOpsPulseSection
                        posSaleSection
                        posReturnSection
                        pointShiftSection
                        pointRequestSection
                        pointSaleSection
                        pointReturnSection
                        pointDebtsSection
                        pointProductsSection
                    }
                    .onChange(of: scrollTarget) { _, target in
                        guard let target else { return }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if let success = vm.successMessage {
                    AlertBanner(message: success, style: .info)
                }
                if !canPOSWrite || !canPointWrite {
                    AlertBanner(message: "Нет доступа для части действий в этом модуле.", style: .critical)
                }
                if let prefill = drilldownPrefillMessage {
                    AlertBanner(message: prefill, style: .excellent)
                }
            }
            .padding()
            .background(AppTheme.Colors.surfacePrimary)
        }
        .navigationTitle("POS и Point")
        .task {
            await vm.loadPOSAndPoint()
            if posCompanyId.isEmpty { posCompanyId = vm.posBootstrap?.companies.first?.id ?? "" }
            if posLocationId.isEmpty {
                posLocationId = (vm.posBootstrap?.locations.first { $0.companyId == posCompanyId }?.id)
                    ?? vm.posBootstrap?.locations.first?.id
                    ?? ""
            }
            if posItemId.isEmpty { posItemId = vm.posBootstrap?.items.first?.id ?? "" }
            if shiftOperatorId.isEmpty { shiftOperatorId = vm.pointBootstrap?.operators.first?.id ?? "" }
            if requestItemId.isEmpty { requestItemId = vm.pointProducts.first?.id ?? "" }
            if pointSaleItemId.isEmpty { pointSaleItemId = vm.pointProducts.first?.id ?? "" }
            if pointReturnItemId.isEmpty { pointReturnItemId = vm.pointProducts.first?.id ?? "" }
        }
    }

    private func posItemLabel(_ itemId: String) -> String {
        vm.posBootstrap?.items.first { $0.id == itemId }?.name ?? "Товар"
    }

    private typealias TableCell = (label: String, value: String, color: Color)

    private var pointCatalogTableCells: [TableCell] {
        [
            (label: "Устройство", value: vm.pointBootstrap?.device?.name ?? "—", color: AppTheme.Colors.textSecondary),
            (label: "Компаний", value: "\(vm.pointBootstrap?.companies.count ?? 0)", color: AppTheme.Colors.info),
            (label: "Операторов", value: "\(vm.pointBootstrap?.operators.count ?? 0)", color: AppTheme.Colors.success)
        ]
    }

    private var posSaleSummaryCells: [TableCell] {
        [
            (label: "Итого", value: MoneyFormatter.short(posSaleTotal), color: AppTheme.Colors.success),
            (label: "Количество", value: posQuantity, color: AppTheme.Colors.textSecondary),
            (label: "Товар", value: posItemLabel(posItemId), color: AppTheme.Colors.textPrimary)
        ]
    }

    private var pointWarehouseSaleSummaryCells: [TableCell] {
        let total = (Double(pointSaleQty) ?? 0) * (Double(pointSaleUnitPrice) ?? 0)
        return [
            (label: "Итого", value: MoneyFormatter.short(total), color: AppTheme.Colors.success),
            (label: "Оплата", value: pointSalePayment, color: AppTheme.Colors.textSecondary),
            (label: "Смена", value: pointSaleShift, color: AppTheme.Colors.textSecondary)
        ]
    }

    private var pointWarehouseReturnSummaryCells: [TableCell] {
        let total = (Double(pointReturnQty) ?? 0) * (Double(pointReturnPrice) ?? 0)
        return [
            (label: "Итого", value: MoneyFormatter.short(total), color: AppTheme.Colors.warning),
            (label: "Оплата", value: pointReturnPayment, color: AppTheme.Colors.textSecondary),
            (label: "Смена", value: pointReturnShift, color: AppTheme.Colors.textSecondary)
        ]
    }

    private func pointDebtTableCells(_ debt: PointDebtItem) -> [TableCell] {
        [
            (label: "Клиент", value: debt.debtorName ?? "—", color: AppTheme.Colors.textSecondary),
            (label: "Товар", value: debt.itemName ?? "—", color: AppTheme.Colors.textPrimary),
            (label: "Сумма", value: MoneyFormatter.short(debt.totalAmount ?? 0), color: AppTheme.Colors.error)
        ]
    }

    private func pointProductTableCells(_ p: PointProduct) -> [TableCell] {
        [
            (label: "Название", value: p.name, color: AppTheme.Colors.textPrimary),
            (label: "Штрихкод", value: p.barcode ?? "—", color: AppTheme.Colors.textSecondary),
            (label: "Цена", value: MoneyFormatter.short(p.price ?? 0), color: AppTheme.Colors.success)
        ]
    }

    private var posCatalogSection: some View {
        Section("POS — справочники") {
            SectionHeader(title: "POS — справочники", icon: "pointofsale.fill", iconColor: AppTheme.Colors.accentBlue)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.xs) {
                statTileFilterButton(title: "КОМПАНИЙ", value: "\(vm.posBootstrap?.companies.count ?? 0)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder, filter: .companies)
                statTileFilterButton(title: "ЛОКАЦИЙ", value: "\(vm.posBootstrap?.locations.count ?? 0)", color: AppTheme.Colors.success, bgColor: AppTheme.Colors.successBg, borderColor: AppTheme.Colors.successBorder, filter: .locations)
                statTileFilterButton(title: "ТОВАРОВ", value: "\(vm.posBootstrap?.items.count ?? 0)", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder, filter: .posItems)
                statTileFilterButton(title: "ЧЕКОВ", value: "\(vm.posReceipts?.data.count ?? 0)/\(vm.posReceipts?.total ?? 0)", color: AppTheme.Colors.purple, bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder, filter: .posReceipts)
            }
        }
    }

    private var pointCatalogSection: some View {
        Section("Точка — справочники") {
            SectionHeader(title: "Точка — справочники", icon: "building.2.fill", iconColor: AppTheme.Colors.accentPrimary)
            DataTableRow(cells: pointCatalogTableCells)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppTheme.Spacing.xs) {
                statTileFilterButton(title: "ДОЛГИ", value: "\(vm.pointDebts.count)", color: AppTheme.Colors.error, bgColor: AppTheme.Colors.errorBg, borderColor: AppTheme.Colors.errorBorder, filter: .pointDebts)
                statTileFilterButton(title: "ТОВАРЫ", value: "\(vm.pointProducts.count)", color: AppTheme.Colors.info, bgColor: AppTheme.Colors.infoBg, borderColor: AppTheme.Colors.infoBorder, filter: .pointProducts)
                statTileFilterButton(title: "ВОЗВРАТЫ", value: "\(vm.pointInventoryReturns?.returns.count ?? 0)", color: AppTheme.Colors.warning, bgColor: AppTheme.Colors.warningBg, borderColor: AppTheme.Colors.warningBorder, filter: .pointReturns)
                statTileFilterButton(title: "СКЛАД ROWS", value: "\(vm.pointReports?.warehouse.count ?? 0)", color: AppTheme.Colors.purple, bgColor: AppTheme.Colors.purpleBg, borderColor: AppTheme.Colors.purpleBorder, filter: .warehouse)
            }
        }
    }

    private var opsDrilldownSection: some View {
        Section("Детали по метрике") {
            if let filter = activeOpsFilter {
                HStack {
                    Text(filter.title)
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.textPrimary)
                    Spacer()
                    Button("Сбросить") { activeOpsFilter = nil }
                        .font(AppTheme.Typography.caption)
                }

                drilldownQuickActions(for: filter)

                let rows = drilldownRows(for: filter)
                if rows.isEmpty {
                    Text("Нет данных для выбранного фильтра")
                        .font(AppTheme.Typography.caption)
                        .foregroundStyle(AppTheme.Colors.textMuted)
                } else {
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        DataTableRow(cells: row)
                        if index < rows.count - 1 {
                            Divider().background(AppTheme.Colors.borderSubtle)
                        }
                    }
                }
            } else {
                Text("Нажмите на KPI-тайл выше, чтобы открыть детали")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            }
        }
    }

    @ViewBuilder
    private func drilldownQuickActions(for filter: OpsFilter) -> some View {
        switch filter {
        case .pointProducts:
            HStack(spacing: 8) {
                Menu("В продажу точки") {
                    ForEach(vm.pointProducts.prefix(20)) { product in
                        Button(product.name) {
                            prefillFromDrilldown("Товар добавлен в форму продажи точки.", target: "form.pointSale") {
                                pointSaleItemId = product.id
                            }
                        }
                    }
                }
                Menu("В заявку склада") {
                    ForEach(vm.pointProducts.prefix(20)) { product in
                        Button(product.name) {
                            prefillFromDrilldown("Товар добавлен в форму заявки на склад.", target: "form.pointRequest") {
                                requestItemId = product.id
                            }
                        }
                    }
                }
                Menu("В возврат точки") {
                    ForEach(vm.pointProducts.prefix(20)) { product in
                        Button(product.name) {
                            prefillFromDrilldown("Товар добавлен в форму возврата точки.", target: "form.pointReturn") {
                                pointReturnItemId = product.id
                            }
                        }
                    }
                }
            }
            .font(AppTheme.Typography.caption)
        case .pointDebts:
            Menu("Быстро выбрать долг для удаления") {
                ForEach(filteredPointDebts.prefix(20)) { debt in
                    Button("\(debt.debtorName ?? "Клиент") — \(debt.itemName ?? "Товар")") {
                        prefillFromDrilldown("Долг выбран в форме удаления.", target: "form.pointDebts") {
                            debtDeleteId = debt.id
                        }
                    }
                }
            }
            .font(AppTheme.Typography.caption)
        case .posItems:
            Menu("В POS продажу") {
                ForEach((vm.posBootstrap?.items ?? []).prefix(20)) { item in
                    Button(item.name) {
                        prefillFromDrilldown("Товар добавлен в форму POS продажи.", target: "form.posSale") {
                            posItemId = item.id
                        }
                    }
                }
            }
            .font(AppTheme.Typography.caption)
        default:
            EmptyView()
        }
    }

    private func prefillFromDrilldown(_ message: String, target: String, apply: () -> Void) {
        apply()
        scrollTarget = target
        drilldownPrefillMessage = message
        AppHaptics.selection()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if drilldownPrefillMessage == message {
                drilldownPrefillMessage = nil
            }
        }
    }

    private var pointOpsPulseSection: some View {
        Section("Пульс POS/Point") {
            SectionHeader(title: "Пульс POS/Point", icon: "waveform.path.ecg", iconColor: AppTheme.Colors.warning)
            let rows = recentPOSPointRows
            if rows.isEmpty {
                Text("Пока нет операций")
                    .font(AppTheme.Typography.caption)
                    .foregroundStyle(AppTheme.Colors.textMuted)
            } else {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    HStack(spacing: AppTheme.Spacing.sm) {
                        Image(systemName: row.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(row.color)
                            .frame(width: 28, height: 28)
                            .background(row.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.Radius.small))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                                .font(AppTheme.Typography.captionBold)
                                .foregroundStyle(AppTheme.Colors.textPrimary)
                            Text(row.subtitle)
                                .font(AppTheme.Typography.micro)
                                .foregroundStyle(AppTheme.Colors.textMuted)
                        }
                        Spacer()
                        Text(row.value)
                            .font(AppTheme.Typography.monoCaption)
                            .foregroundStyle(row.color)
                    }
                    if index < rows.count - 1 {
                        Divider().background(AppTheme.Colors.borderSubtle)
                    }
                }
            }
        }
    }

    private var posSaleSection: some View {
        Section("POS: Продажа") {
            SectionHeader(title: "POS: продажа", icon: "cart.fill.badge.plus", iconColor: AppTheme.Colors.success)
            posSalePickerFields
            posSaleAmountFields
            posSaleSummary
            posSaleSubmitButton
        }
        .id("form.posSale")
    }

    private struct POSPointPulseRow: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let value: String
        let icon: String
        let color: Color
    }

    private var recentPOSPointRows: [POSPointPulseRow] {
        var rows: [POSPointPulseRow] = []

        for receipt in (vm.posReceipts?.data ?? []).prefix(3) {
            rows.append(
                POSPointPulseRow(
                    id: "sale-\(receipt.id)",
                    title: "POS продажа",
                    subtitle: receipt.saleDate?.prefix(10).description ?? "—",
                    value: MoneyFormatter.short(receipt.totalAmount ?? 0),
                    icon: "cart.fill.badge.plus",
                    color: AppTheme.Colors.success
                )
            )
        }

        for ret in (vm.pointInventoryReturns?.returns ?? []).prefix(2) {
            rows.append(
                POSPointPulseRow(
                    id: "return-\(ret.id)",
                    title: "Возврат точки",
                    subtitle: "ID: \(ret.id.prefix(8))",
                    value: MoneyFormatter.short(ret.totalAmount ?? 0),
                    icon: "arrow.uturn.backward.circle.fill",
                    color: AppTheme.Colors.warning
                )
            )
        }

        for debt in vm.pointDebts.prefix(2) {
            rows.append(
                POSPointPulseRow(
                    id: "debt-\(debt.id)",
                    title: debt.debtorName ?? "Долг клиента",
                    subtitle: debt.itemName ?? "Товар",
                    value: MoneyFormatter.short(debt.totalAmount ?? 0),
                    icon: "exclamationmark.circle.fill",
                    color: AppTheme.Colors.error
                )
            )
        }

        return Array(rows.prefix(7))
    }

    private enum OpsFilter: String {
        case companies
        case locations
        case posItems
        case posReceipts
        case pointDebts
        case pointProducts
        case pointReturns
        case warehouse

        var title: String {
            switch self {
            case .companies: return "Компании POS"
            case .locations: return "Локации POS"
            case .posItems: return "Товары POS"
            case .posReceipts: return "Чеки POS"
            case .pointDebts: return "Долги точки"
            case .pointProducts: return "Товары точки"
            case .pointReturns: return "Возвраты точки"
            case .warehouse: return "Складские остатки точки"
            }
        }
    }

    @ViewBuilder
    private func statTileFilterButton(
        title: String,
        value: String,
        color: Color,
        bgColor: Color,
        borderColor: Color,
        filter: OpsFilter
    ) -> some View {
        Button {
            activeOpsFilter = (activeOpsFilter == filter) ? nil : filter
        } label: {
            StatTile(title: title, value: value, color: color, bgColor: bgColor, borderColor: borderColor)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.Radius.medium)
                        .stroke(activeOpsFilter == filter ? color.opacity(0.8) : .clear, lineWidth: 2)
                )
        }
        .buttonStyle(.plain)
    }

    private func drilldownRows(for filter: OpsFilter) -> [[TableCell]] {
        switch filter {
        case .companies:
            return (vm.posBootstrap?.companies ?? []).prefix(10).map { c in
                [
                    (label: "ID", value: c.id, color: AppTheme.Colors.textMuted),
                    (label: "Название", value: c.name, color: AppTheme.Colors.textPrimary),
                    (label: "Код", value: c.code ?? "—", color: AppTheme.Colors.info),
                ]
            }
        case .locations:
            return (vm.posBootstrap?.locations ?? []).prefix(10).map { l in
                [
                    (label: "Локация", value: l.name, color: AppTheme.Colors.textPrimary),
                    (label: "Компания", value: l.companyId ?? "—", color: AppTheme.Colors.textSecondary),
                    (label: "Активна", value: l.isActiveResolved ? "Да" : "Нет", color: l.isActiveResolved ? AppTheme.Colors.success : AppTheme.Colors.warning),
                ]
            }
        case .posItems:
            return (vm.posBootstrap?.items ?? []).prefix(10).map { item in
                [
                    (label: "Товар", value: item.name, color: AppTheme.Colors.textPrimary),
                    (label: "Цена", value: MoneyFormatter.short(item.salePrice ?? 0), color: AppTheme.Colors.success),
                    (label: "Остаток", value: String(format: "%.2f", item.totalBalance ?? 0), color: AppTheme.Colors.info),
                ]
            }
        case .posReceipts:
            return (vm.posReceipts?.data ?? []).prefix(10).map { receipt in
                [
                    (label: "Чек", value: receipt.id, color: AppTheme.Colors.textMuted),
                    (label: "Дата", value: receipt.saleDate ?? "—", color: AppTheme.Colors.textSecondary),
                    (label: "Сумма", value: MoneyFormatter.short(receipt.totalAmount ?? 0), color: AppTheme.Colors.success),
                ]
            }
        case .pointDebts:
            return vm.pointDebts.prefix(10).map { debt in
                pointDebtTableCells(debt)
            }
        case .pointProducts:
            return vm.pointProducts.prefix(10).map { p in
                pointProductTableCells(p)
            }
        case .pointReturns:
            return (vm.pointInventoryReturns?.returns ?? []).prefix(10).map { ret in
                [
                    (label: "Возврат", value: ret.id, color: AppTheme.Colors.textMuted),
                    (label: "Сумма", value: MoneyFormatter.short(ret.totalAmount ?? 0), color: AppTheme.Colors.warning),
                    (label: "Статус", value: "done", color: AppTheme.Colors.success),
                ]
            }
        case .warehouse:
            return (vm.pointReports?.warehouse ?? []).prefix(10).map { w in
                [
                    (label: "Товар", value: w.itemName, color: AppTheme.Colors.textPrimary),
                    (label: "ШК", value: w.barcode ?? "—", color: AppTheme.Colors.textMuted),
                    (label: "Кол-во", value: String(format: "%.2f", w.quantity), color: AppTheme.Colors.info),
                ]
            }
        }
    }

    private var posReturnSection: some View {
        Section("POS: Возврат") {
            SectionHeader(title: "POS: возврат", icon: "arrow.uturn.backward.circle.fill", iconColor: AppTheme.Colors.warning)
            TextField("Номер чека", text: $returnSaleId).appInputStyle()
            TextField("Или короткий код", text: $returnShortId).appInputStyle()
            Button("Найти чек") {
                Task { await vm.lookupReturn(saleId: returnSaleId.isEmpty ? nil : returnSaleId, shortId: returnShortId.isEmpty ? nil : returnShortId) }
            }
            .buttonStyle(.bordered)
            if let lookup = vm.returnLookup {
                SecondaryChip(text: "Чек: \(lookup.id)", color: AppTheme.Colors.info)
                Picker("Позиция в чеке", selection: $returnItemId) {
                    Text("Выберите позицию").tag("")
                    ForEach(lookup.items) { item in
                        Text("\(posItemLabel(item.itemId)) · \(item.quantity, specifier: "%.2f") шт.")
                            .tag(item.itemId)
                    }
                }
                .pickerStyle(.menu)
                TextField("Количество", text: $returnQty).keyboardType(.decimalPad).appInputStyle()
                TextField("Цена", text: $returnUnitPrice).keyboardType(.decimalPad).appInputStyle()
                TextField("Причина", text: $returnReason).appInputStyle()
                if let item = selectedReturnLookupItem {
                    DataTableRow(cells: [
                        (label: "Выбрано", value: posItemLabel(item.itemId), color: AppTheme.Colors.textPrimary),
                        (label: "В чеке", value: String(format: "%.2f", item.quantity), color: AppTheme.Colors.textSecondary),
                        (label: "Возврат", value: String(format: "%.2f", Double(returnQty) ?? 0), color: AppTheme.Colors.warning),
                    ])
                }
                if !(Double(returnQty) ?? 0 > 0) {
                    AlertBanner(message: "Количество возврата должно быть больше нуля.", style: .warning)
                }
                Button("Создать возврат") {
                    guard canPOSWrite else {
                        vm.errorMessage = "Нет доступа для этой роли."
                        return
                    }
                    guard !returnItemId.isEmpty else {
                        vm.errorMessage = "Выберите товар для возврата."
                        return
                    }
                    guard (Double(returnQty) ?? 0) > 0 else {
                        vm.errorMessage = "Количество возврата должно быть больше нуля."
                        return
                    }
                    Task {
                        await vm.createReturn(
                            saleId: lookup.id,
                            itemId: returnItemId,
                            quantity: Double(returnQty) ?? 0,
                            unitPrice: Double(returnUnitPrice) ?? 0,
                            reason: returnReason
                        )
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canPOSWrite)
            }
        }
    }

    private var pointShiftSection: some View {
        Section("Точка: сменный отчет") {
            SectionHeader(title: "Точка: сменный отчет", icon: "doc.text.magnifyingglass", iconColor: AppTheme.Colors.accentBlue)
            DatePicker("Дата", selection: $shiftOperationDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ru_RU"))
            Picker("Оператор", selection: $shiftOperatorId) {
                Text("Выберите оператора").tag("")
                ForEach(vm.pointBootstrap?.operators ?? []) { op in
                    Text(op.name).tag(op.id)
                }
            }
            .pickerStyle(.menu)
            Picker("Смена", selection: $shiftType) {
                Text("День").tag("day")
                Text("Ночь").tag("night")
            }
            .pickerStyle(.segmented)
            TextField("Наличные", text: $shiftCash).keyboardType(.decimalPad).appInputStyle()
            TextField("Kaspi", text: $shiftKaspi).keyboardType(.decimalPad).appInputStyle()
            TextField("Online", text: $shiftOnline).keyboardType(.decimalPad).appInputStyle()
            TextField("Карта", text: $shiftCard).keyboardType(.decimalPad).appInputStyle()
            DataTableRow(cells: [
                (label: "Итого смены", value: MoneyFormatter.short(shiftTotalAmount), color: AppTheme.Colors.success),
                (label: "Смена", value: shiftType == "day" ? "День" : "Ночь", color: AppTheme.Colors.textSecondary),
                (label: "Оператор", value: selectedOperatorName, color: AppTheme.Colors.textPrimary),
            ])
            if let reports = vm.pointReports {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Быстрый срез по точке")
                        .font(AppTheme.Typography.captionBold)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                    if let topWorker = reports.workerTotals.sorted(by: { $0.totalAmount > $1.totalAmount }).first {
                        Text("Топ оператор: \(topWorker.name) · \(MoneyFormatter.short(topWorker.totalAmount))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                    if let topClient = reports.clientTotals.sorted(by: { $0.totalAmount > $1.totalAmount }).first {
                        Text("Топ клиент: \(topClient.name) · \(MoneyFormatter.short(topClient.totalAmount))")
                            .font(AppTheme.Typography.caption)
                            .foregroundStyle(AppTheme.Colors.textMuted)
                    }
                }
            }
            TextField("Комментарий", text: $shiftComment).appInputStyle()
            Button("Отправить сменный отчет") {
                guard canPointWrite else {
                    vm.errorMessage = "Нет доступа для этой роли."
                    return
                }
                guard !shiftOperatorId.isEmpty else {
                    vm.errorMessage = "Выберите оператора."
                    return
                }
                Task {
                    await vm.createPointShiftReport(
                        date: P0APIDateFormatter.yyyyMMdd.string(from: shiftOperationDate),
                        operatorId: shiftOperatorId,
                        shift: shiftType,
                        cash: Double(shiftCash) ?? 0,
                        kaspi: Double(shiftKaspi) ?? 0,
                        online: Double(shiftOnline) ?? 0,
                        card: Double(shiftCard) ?? 0,
                        comment: shiftComment
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPointWrite)
        }
    }

    private var shiftTotalAmount: Double {
        let cash: Double = Double(shiftCash) ?? 0
        let kaspi: Double = Double(shiftKaspi) ?? 0
        let online: Double = Double(shiftOnline) ?? 0
        let card: Double = Double(shiftCard) ?? 0
        return cash + kaspi + online + card
    }

    private var selectedOperatorName: String {
        vm.pointBootstrap?.operators.first(where: { $0.id == shiftOperatorId })?.name ?? "—"
    }

    private var pointRequestSection: some View {
        Section("Точка: заявка на склад") {
            SectionHeader(title: "Точка: заявка на склад", icon: "tray.and.arrow.up.fill", iconColor: AppTheme.Colors.purple)
            Picker("Товар", selection: $requestItemId) {
                Text("Выберите товар").tag("")
                ForEach(vm.pointProducts) { product in
                    Text(product.name).tag(product.id)
                }
            }
            .pickerStyle(.menu)
            HStack(spacing: AppTheme.Spacing.sm) {
                Button {
                    let current = max(0, Double(requestQty) ?? 0)
                    requestQty = String(format: "%.2f", max(0, current - 1))
                } label: {
                    Image(systemName: "minus.circle.fill")
                }
                .buttonStyle(.plain)

                TextField("Количество", text: $requestQty).keyboardType(.decimalPad).appInputStyle()

                Button {
                    let current = max(0, Double(requestQty) ?? 0)
                    requestQty = String(format: "%.2f", current + 1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(AppTheme.Colors.accentBlue)
            if let selected = selectedRequestProduct {
                DataTableRow(cells: [
                    (label: "Товар", value: selected.name, color: AppTheme.Colors.textPrimary),
                    (label: "ШК", value: selected.barcode ?? "—", color: AppTheme.Colors.textSecondary),
                    (label: "Цена", value: MoneyFormatter.short(selected.price ?? 0), color: AppTheme.Colors.success),
                ])
            }
            TextField("Комментарий", text: $requestComment).appInputStyle()
            Button("Создать заявку") {
                guard canPointWrite else {
                    vm.errorMessage = "Нет доступа для этой роли."
                    return
                }
                guard !requestItemId.isEmpty else {
                    vm.errorMessage = "Выберите товар."
                    return
                }
                guard (Double(requestQty) ?? 0) > 0 else {
                    vm.errorMessage = "Количество должно быть больше нуля."
                    return
                }
                Task {
                    await vm.createPointInventoryRequest(
                        itemId: requestItemId,
                        requestedQty: Double(requestQty) ?? 0,
                        comment: requestComment
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPointWrite)
        }
        .id("form.pointRequest")
    }

    private var pointSaleSection: some View {
        Section("Точка: продажа (склад)") {
            SectionHeader(title: "Точка: продажа (склад)", icon: "shippingbox.and.arrow.forward.fill", iconColor: AppTheme.Colors.success)
            DatePicker("Дата", selection: $pointSaleOperationDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ru_RU"))
            Picker("Смена", selection: $pointSaleShift) {
                Text("День").tag("day")
                Text("Ночь").tag("night")
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                quickChoiceChip("День", isActive: pointSaleShift == "day") { pointSaleShift = "day" }
                quickChoiceChip("Ночь", isActive: pointSaleShift == "night") { pointSaleShift = "night" }
            }
            Picker("Оплата", selection: $pointSalePayment) {
                Text("Наличные").tag("cash")
                Text("Kaspi").tag("kaspi")
                Text("Смешанная").tag("mixed")
            }
            .pickerStyle(.menu)
            HStack(spacing: 8) {
                quickChoiceChip("Cash", isActive: pointSalePayment == "cash") { pointSalePayment = "cash" }
                quickChoiceChip("Kaspi", isActive: pointSalePayment == "kaspi") { pointSalePayment = "kaspi" }
                quickChoiceChip("Mixed", isActive: pointSalePayment == "mixed") { pointSalePayment = "mixed" }
            }
            Picker("Товар", selection: $pointSaleItemId) {
                Text("Выберите товар").tag("")
                ForEach(vm.pointProducts) { product in
                    Text(product.name).tag(product.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Количество", text: $pointSaleQty).keyboardType(.decimalPad).appInputStyle()
            TextField("Цена", text: $pointSaleUnitPrice).keyboardType(.decimalPad).appInputStyle()
            DataTableRow(cells: pointWarehouseSaleSummaryCells)
            if !(Double(pointSaleQty) ?? 0 > 0) || !(Double(pointSaleUnitPrice) ?? 0 > 0) {
                AlertBanner(message: "Количество и цена должны быть больше нуля.", style: .warning)
            }
            Button("Создать продажу точки") {
                guard canPointWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
                guard !pointSaleItemId.isEmpty else {
                    vm.errorMessage = "Выберите товар."
                    return
                }
                guard (Double(pointSaleQty) ?? 0) > 0, (Double(pointSaleUnitPrice) ?? 0) > 0 else {
                    vm.errorMessage = "Количество и цена должны быть больше нуля."
                    return
                }
                Task {
                    await vm.createPointInventorySale(
                        date: P0APIDateFormatter.yyyyMMdd.string(from: pointSaleOperationDate),
                        shift: pointSaleShift,
                        payment: pointSalePayment,
                        itemId: pointSaleItemId,
                        quantity: Double(pointSaleQty) ?? 0,
                        unitPrice: Double(pointSaleUnitPrice) ?? 0
                    )
                }
            }.buttonStyle(.borderedProminent).disabled(!canPointWrite)
        }
        .id("form.pointSale")
    }

    private var pointReturnSection: some View {
        Section("Точка: возврат (склад)") {
            SectionHeader(title: "Точка: возврат (склад)", icon: "arrow.uturn.backward.square.fill", iconColor: AppTheme.Colors.warning)
            TextField("Номер продажи", text: $pointReturnSaleId).appInputStyle()
            DatePicker("Дата", selection: $pointReturnOperationDate, displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ru_RU"))
            Picker("Смена", selection: $pointReturnShift) {
                Text("День").tag("day")
                Text("Ночь").tag("night")
            }
            .pickerStyle(.segmented)
            HStack(spacing: 8) {
                quickChoiceChip("День", isActive: pointReturnShift == "day") { pointReturnShift = "day" }
                quickChoiceChip("Ночь", isActive: pointReturnShift == "night") { pointReturnShift = "night" }
            }
            Picker("Оплата", selection: $pointReturnPayment) {
                Text("Наличные").tag("cash")
                Text("Kaspi").tag("kaspi")
                Text("Смешанная").tag("mixed")
            }
            .pickerStyle(.menu)
            HStack(spacing: 8) {
                quickChoiceChip("Cash", isActive: pointReturnPayment == "cash") { pointReturnPayment = "cash" }
                quickChoiceChip("Kaspi", isActive: pointReturnPayment == "kaspi") { pointReturnPayment = "kaspi" }
                quickChoiceChip("Mixed", isActive: pointReturnPayment == "mixed") { pointReturnPayment = "mixed" }
            }
            Picker("Товар", selection: $pointReturnItemId) {
                Text("Выберите товар").tag("")
                ForEach(vm.pointProducts) { product in
                    Text(product.name).tag(product.id)
                }
            }
            .pickerStyle(.menu)
            TextField("Количество", text: $pointReturnQty).keyboardType(.decimalPad).appInputStyle()
            TextField("Цена", text: $pointReturnPrice).keyboardType(.decimalPad).appInputStyle()
            DataTableRow(cells: pointWarehouseReturnSummaryCells)
            if !(Double(pointReturnQty) ?? 0 > 0) || !(Double(pointReturnPrice) ?? 0 > 0) {
                AlertBanner(message: "Количество и цена возврата должны быть больше нуля.", style: .warning)
            }
            Button("Создать возврат точки") {
                guard canPointWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
                guard !pointReturnSaleId.isEmpty, !pointReturnItemId.isEmpty else {
                    vm.errorMessage = "Укажите номер продажи и выберите товар."
                    return
                }
                guard (Double(pointReturnQty) ?? 0) > 0, (Double(pointReturnPrice) ?? 0) > 0 else {
                    vm.errorMessage = "Количество и цена возврата должны быть больше нуля."
                    return
                }
                Task {
                    await vm.createPointInventoryReturn(
                        saleId: pointReturnSaleId,
                        date: P0APIDateFormatter.yyyyMMdd.string(from: pointReturnOperationDate),
                        shift: pointReturnShift,
                        payment: pointReturnPayment,
                        itemId: pointReturnItemId,
                        quantity: Double(pointReturnQty) ?? 0,
                        unitPrice: Double(pointReturnPrice) ?? 0
                    )
                }
            }.buttonStyle(.bordered).disabled(!canPointWrite)
        }
        .id("form.pointReturn")
    }

    @ViewBuilder
    private func quickChoiceChip(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTheme.Typography.captionBold)
                .foregroundStyle(isActive ? .white : AppTheme.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isActive ? AnyShapeStyle(AppTheme.Colors.accentBlue) : AnyShapeStyle(AppTheme.Colors.surfaceSecondary))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var pointDebtsSection: some View {
        Section("Точка: долги") {
            SectionHeader(title: "Долги клиентов", icon: "exclamationmark.circle.fill", iconColor: AppTheme.Colors.error)
            AppSearchBar(text: $debtSearchQuery, placeholder: "Поиск: клиент или товар")
            pointDebtCreateForm
            pointDebtDeleteControls
            pointDebtPreview
        }
        .id("form.pointDebts")
    }

    private var posSalePickerFields: some View {
        Group {
            Picker("Компания", selection: $posCompanyId) {
                Text("Выберите компанию").tag("")
                ForEach(vm.posBootstrap?.companies ?? []) { company in
                    Text(company.name).tag(company.id)
                }
            }
            .pickerStyle(.menu)
            Picker("Локация", selection: $posLocationId) {
                Text("Выберите локацию").tag("")
                ForEach((vm.posBootstrap?.locations ?? []).filter { location in
                    posCompanyId.isEmpty || location.companyId == posCompanyId
                }) { location in
                    Text(location.name).tag(location.id)
                }
            }
            .pickerStyle(.menu)
            Picker("Товар", selection: $posItemId) {
                Text("Выберите товар").tag("")
                ForEach(vm.posBootstrap?.items ?? []) { item in
                    Text(item.name).tag(item.id)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var posSaleAmountFields: some View {
        Group {
            TextField("Количество", text: $posQuantity).keyboardType(.decimalPad).appInputStyle()
            TextField("Наличные", text: $posCash).keyboardType(.decimalPad).appInputStyle()
            TextField("Kaspi", text: $posKaspi).keyboardType(.decimalPad).appInputStyle()
            TextField("Online", text: $posOnline).keyboardType(.decimalPad).appInputStyle()
            TextField("Карта", text: $posCard).keyboardType(.decimalPad).appInputStyle()
            TextField("Комментарий", text: $posNote).appInputStyle()
        }
    }

    private var posSaleTotal: Double {
        let a = Double(posCash) ?? 0
        let b = Double(posKaspi) ?? 0
        let c = Double(posOnline) ?? 0
        let d = Double(posCard) ?? 0
        return a + b + c + d
    }

    private var posSaleSummary: some View {
        DataTableRow(cells: posSaleSummaryCells)
    }

    private var selectedReturnLookupItem: POSReturnLookupItem? {
        vm.returnLookup?.items.first(where: { $0.itemId == returnItemId })
    }

    private var posSaleSubmitButton: some View {
        Button("Провести продажу") {
            guard canPOSWrite else {
                vm.errorMessage = "Нет доступа для этой роли."
                return
            }
            guard !posCompanyId.isEmpty, !posLocationId.isEmpty, !posItemId.isEmpty else {
                vm.errorMessage = "Выберите компанию, локацию и товар."
                return
            }
            Task {
                await vm.createSale(
                    companyId: posCompanyId,
                    locationId: posLocationId,
                    itemId: posItemId,
                    quantity: Double(posQuantity) ?? 0,
                    cash: Double(posCash) ?? 0,
                    kaspi: Double(posKaspi) ?? 0,
                    online: Double(posOnline) ?? 0,
                    card: Double(posCard) ?? 0,
                    note: posNote
                )
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(!canPOSWrite)
    }

    private var pointDebtCreateForm: some View {
        Group {
            TextField("Клиент", text: $debtClientName).appInputStyle()
            TextField("Товар", text: $debtItemName).appInputStyle()
            TextField("Количество", text: $debtQty).keyboardType(.decimalPad).appInputStyle()
            TextField("Цена", text: $debtPrice).keyboardType(.decimalPad).appInputStyle()
            Button("Создать долг") {
                guard canPointWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
                Task {
                    await vm.createPointDebt(
                        clientName: debtClientName,
                        itemName: debtItemName,
                        quantity: Double(debtQty) ?? 0,
                        unitPrice: Double(debtPrice) ?? 0
                    )
                }
            }.buttonStyle(.borderedProminent).disabled(!canPointWrite)
        }
    }

    private var pointDebtDeleteControls: some View {
        Group {
            Picker("Удалить запись", selection: $debtDeleteId) {
                Text("Выберите долг").tag("")
                ForEach(filteredPointDebts) { debt in
                    Text("\(debt.debtorName ?? "Клиент") — \(debt.itemName ?? "Товар")")
                        .tag(debt.id)
                }
            }
            .pickerStyle(.menu)
            Button("Удалить долг") {
                guard canPointWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
                guard !debtDeleteId.isEmpty else {
                    vm.errorMessage = "Выберите запись долга."
                    return
                }
                Task { await vm.deletePointDebt(itemId: debtDeleteId) }
            }.buttonStyle(.bordered).disabled(!canPointWrite)
        }
    }

    @ViewBuilder
    private var pointDebtPreview: some View {
        if filteredPointDebts.isEmpty {
            Text("Совпадений не найдено")
                .font(AppTheme.Typography.caption)
                .foregroundStyle(AppTheme.Colors.textMuted)
        } else {
            ForEach(filteredPointDebts.prefix(8)) { debt in
                DataTableRow(cells: pointDebtTableCells(debt))
            }
        }
    }

    private var selectedRequestProduct: PointProduct? {
        vm.pointProducts.first(where: { $0.id == requestItemId })
    }

    private var filteredPointDebts: [PointDebtItem] {
        let q = debtSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.pointDebts }
        return vm.pointDebts.filter { debt in
            (debt.debtorName ?? "").lowercased().contains(q)
                || (debt.itemName ?? "").lowercased().contains(q)
                || debt.id.lowercased().contains(q)
        }
    }

    private var pointProductsSection: some View {
        Section("Точка: товары") {
            SectionHeader(title: "Товары точки", icon: "shippingbox.fill", iconColor: AppTheme.Colors.success)
            TextField("Название товара", text: $productName).appInputStyle()
            TextField("Штрихкод", text: $productBarcode).appInputStyle()
            TextField("Цена", text: $productPrice).keyboardType(.decimalPad).appInputStyle()
            Button("Добавить товар") {
                guard canPointWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
                guard !productName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    vm.errorMessage = "Введите название товара."
                    return
                }
                guard (Double(productPrice) ?? 0) > 0 else {
                    vm.errorMessage = "Цена должна быть больше нуля."
                    return
                }
                Task {
                    await vm.createPointProduct(
                        name: productName,
                        barcode: productBarcode,
                        price: Double(productPrice) ?? 0
                    )
                    if vm.errorMessage == nil {
                        productName = ""
                        productBarcode = ""
                        productPrice = "0"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPointWrite)

            Picker("Удалить товар", selection: $productDeleteId) {
                Text("Выберите товар").tag("")
                ForEach(vm.pointProducts) { p in
                    Text("\(p.name) · \(MoneyFormatter.short(p.price ?? 0))").tag(p.id)
                }
            }
            .pickerStyle(.menu)
            Button("Удалить товар") {
                guard canPointWrite else { vm.errorMessage = "Нет доступа для этой роли."; return }
                guard !productDeleteId.isEmpty else {
                    vm.errorMessage = "Выберите товар для удаления."
                    return
                }
                Task { await vm.deletePointProduct(productId: productDeleteId) }
            }
            .buttonStyle(.bordered)
            .disabled(!canPointWrite)

            Divider().background(AppTheme.Colors.borderSubtle)

            ForEach(vm.pointProducts.prefix(12)) { p in
                DataTableRow(cells: pointProductTableCells(p))
            }
        }
    }

    private var canPOSWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminPOSWrite)
    }

    private var canPointWrite: Bool {
        CapabilityMatrix.capabilities(for: sessionStore.roleContext).contains(.adminPointWrite)
    }
}
