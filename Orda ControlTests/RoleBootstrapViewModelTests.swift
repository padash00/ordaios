import XCTest
@testable import Orda_Control

@MainActor
final class RoleBootstrapViewModelTests: XCTestCase {
    func testSessionStoreLoginBootstrapsSuperAdminShell() async throws {
        let apiClient = APIClient(config: .testBootstrap)
        let auth = BootstrapAuthService()
        let verifier = BootstrapVerifier(
            context: SessionRoleContext(
                isSuperAdmin: true,
                isStaff: true,
                isOperator: false,
                isCustomer: false,
                persona: "super_admin",
                staffRole: "owner",
                roleLabel: "Супер-администратор",
                defaultPath: "/dashboard",
                organizations: nil,
                activeOrganization: nil,
                activeSubscription: nil,
                rolePermissionOverrides: nil
            )
        )
        let store = SessionStore(
            apiClient: apiClient,
            authService: auth,
            backendSessionVerifier: verifier,
            registrationService: BootstrapRegistrationService(),
            keychainStorage: BootstrapKeychain()
        )

        try await store.login(email: "admin@test.com", password: "123456")

        XCTAssertEqual(store.shellType, .admin)
        XCTAssertEqual(store.roleContext?.persona, "super_admin")
    }
}

private extension AppConfig {
    static var testBootstrap: AppConfig {
        AppConfig(
            environment: .development,
            apiBaseURL: URL(string: "https://www.ordaops.kz")!,
            supabaseURL: URL(string: "https://example.supabase.co")!,
            supabaseAnonKey: "test-key",
            passwordResetRedirectURL: "orda-control://auth/reset-password"
        )
    }
}

private final class BootstrapAuthService: AuthServicing {
    func signIn(email: String, password: String) async throws -> Session {
        Session(accessToken: "token", refreshToken: "refresh", expiresIn: 3600, userEmail: email)
    }
    func refreshSession(refreshToken: String) async throws -> Session {
        Session(accessToken: "token2", refreshToken: refreshToken, expiresIn: 3600, userEmail: "admin@test.com")
    }
    func signUp(email: String, password: String) async throws -> Session? { nil }
    func resendConfirmation(email: String) async throws {}
    func requestPasswordReset(email: String, redirectTo: String) async throws {}
    func updatePassword(accessToken: String, newPassword: String) async throws {}
    func verifyRecoveryTokenHash(_ tokenHash: String) async throws -> Session {
        Session(accessToken: "recovery-token", refreshToken: nil, expiresIn: 3600, userEmail: "admin@test.com")
    }
}

private final class BootstrapVerifier: BackendSessionVerifying {
    let context: SessionRoleContext
    init(context: SessionRoleContext) { self.context = context }
    func fetchSessionRole(userEmail: String) async throws -> SessionRoleContext { context }
}

private final class BootstrapRegistrationService: RegistrationServicing {
    func fetchOptions() async throws -> ClientRegistrationOptionsResponse {
        ClientRegistrationOptionsResponse(companies: [], points: [])
    }
    func registerClient(body: ClientRegisterRequest) async throws {}
}

private final class BootstrapKeychain: KeychainStoring {
    func save(_ data: Data, for key: String) throws {}
    func read(for key: String) throws -> Data? { nil }
    func delete(for key: String) throws {}
}
