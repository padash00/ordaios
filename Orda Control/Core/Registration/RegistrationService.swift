import Foundation

protocol RegistrationServicing {
    func fetchOptions() async throws -> ClientRegistrationOptionsResponse
    func registerClient(body: ClientRegisterRequest) async throws
}

final class RegistrationService: RegistrationServicing {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchOptions() async throws -> ClientRegistrationOptionsResponse {
        let endpoint = APIEndpoint(path: "/api/public/client/options", method: .GET)
        return try await apiClient.request(endpoint)
    }

    func registerClient(body: ClientRegisterRequest) async throws {
        let endpoint = APIEndpoint(path: "/api/public/client/register", method: .POST)
        let _: APIStatusResponse = try await apiClient.request(endpoint, body: body)
    }
}
