import Foundation

protocol SupportServicing {
    func fetchRequests(limit: Int, offset: Int) async throws -> SupportResponse
    func send(message: String, companyId: String?) async throws
}

final class SupportService: SupportServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchRequests(limit: Int, offset: Int) async throws -> SupportResponse {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        let endpoint = APIEndpoint(path: "/api/client/support?limit=\(safeLimit)&offset=\(safeOffset)", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func send(message: String, companyId: String?) async throws {
        let endpoint = APIEndpoint(path: "/api/client/support", method: .POST)
        let trimmed = companyId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cid = trimmed.isEmpty ? nil : trimmed
        let body = CreateSupportRequest(message: message, companyId: cid)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }
}
