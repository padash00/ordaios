import Foundation

protocol BackendSessionVerifying {
    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext
}

final class BackendSessionVerifier: BackendSessionVerifying {
    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext {
        let endpoint = APIEndpoint(path: "/api/auth/session-role", method: .GET)
        let role: SessionRoleContext = try await apiClient.request(endpoint)

        #if DEBUG
        print("=== SESSION ROLE DEBUG ===")
        print("email:", userEmail)
        print("isSuperAdmin:", role.isSuperAdmin)
        print("isStaff:", role.isStaff)
        print("isOperator:", role.isOperator)
        print("isCustomer:", role.isCustomer)
        print("persona:", role.persona ?? "nil")
        print("defaultPath:", role.defaultPath ?? "nil")
        #endif

        return role
    }
}
