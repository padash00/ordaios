import Foundation

protocol AdminClientSupportServicing {
    func fetchTickets(limit: Int, offset: Int) async throws -> AdminSupportResponse
    func setStatus(requestId: String, status: String, priority: String?, assignedStaffId: String?) async throws
}

final class AdminClientSupportService: AdminClientSupportServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchTickets(limit: Int, offset: Int) async throws -> AdminSupportResponse {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        let endpoint = APIEndpoint(path: "/api/admin/client/support?limit=\(safeLimit)&offset=\(safeOffset)", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func setStatus(requestId: String, status: String, priority: String?, assignedStaffId: String?) async throws {
        let endpoint = APIEndpoint(path: "/api/admin/client/support", method: .POST)
        let body = AdminSupportStatusRequest(
            action: "setStatus",
            ticketId: requestId,
            status: status,
            priority: priority,
            assignedStaffId: assignedStaffId
        )
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }
}
